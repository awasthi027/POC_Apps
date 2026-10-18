package com.ashi.service.infrastructure.crypto;

import com.ashi.service.application.port.AttestationCryptoPort;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.dataformat.cbor.databind.CBORMapper;
import org.bouncycastle.asn1.ASN1Encodable;
import org.bouncycastle.asn1.ASN1OctetString;
import org.bouncycastle.asn1.ASN1Primitive;
import org.bouncycastle.asn1.ASN1Sequence;
import org.bouncycastle.asn1.ASN1Set;
import org.bouncycastle.asn1.ASN1TaggedObject;

import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.security.AlgorithmParameters;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PublicKey;
import java.security.Signature;
import java.security.cert.CertPath;
import java.security.cert.CertPathValidator;
import java.security.cert.CertificateFactory;
import java.security.cert.PKIXParameters;
import java.security.cert.TrustAnchor;
import java.security.cert.X509Certificate;
import java.security.spec.ECGenParameterSpec;
import java.security.spec.ECParameterSpec;
import java.security.spec.ECPublicKeySpec;
import java.security.spec.InvalidKeySpecException;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Set;

public final class AttestationCrypto implements AttestationCryptoPort {
    private static final String APPLE_APP_ATTESTATION_ROOT_CA_PEM = """
            -----BEGIN CERTIFICATE-----
            MIICITCCAaegAwIBAgIQC/O+DvHN0uD7jG5yH2IXmDAKBggqhkjOPQQDAzBSMSYw
            JAYDVQQDDB1BcHBsZSBBcHAgQXR0ZXN0YXRpb24gUm9vdCBDQTETMBEGA1UECgwK
            QXBwbGUgSW5jLjETMBEGA1UECAwKQ2FsaWZvcm5pYTAeFw0yMDAzMTgxODMyNTNa
            Fw00NTAzMTUwMDAwMDBaMFIxJjAkBgNVBAMMHUFwcGxlIEFwcCBBdHRlc3RhdGlv
            biBSb290IENBMRMwEQYDVQQKDApBcHBsZSBJbmMuMRMwEQYDVQQIDApDYWxpZm9y
            bmlhMHYwEAYHKoZIzj0CAQYFK4EEACIDYgAERTHhmLW07ATaFQIEVwTtT4dyctdh
            NbJhFs/Ii2FdCgAHGbpphY3+d8qjuDngIN3WVhQUBHAoMeQ/cLiP1sOUtgjqK9au
            Yen1mMEvRq9Sk3Jm5X8U62H+xTD3FE9TgS41o0IwQDAPBgNVHRMBAf8EBTADAQH/
            MB0GA1UdDgQWBBSskRBTM72+aEH/pwyp5frq5eWKoTAOBgNVHQ8BAf8EBAMCAQYw
            CgYIKoZIzj0EAwMDaAAwZQIwQgFGnByvsiVbpTKwSga0kP0e8EeDS4+sQmTvb7vn
            53O5+FRXgeLhpJ06ysC5PrOyAjEAp5U4xDgEgllF7En3VcE3iexZZtKeYnpqtijV
            oyFraWVIyd/dganmrduC1bmTBGwD
            -----END CERTIFICATE-----
            """;
    private static final int RP_ID_HASH_LENGTH = 32;
    private static final int COUNTER_OFFSET = 33;
    private static final int AUTH_DATA_MIN_LENGTH = 37;
    private static final int FLAG_OFFSET = 32;
    private static final int FLAG_ATTESTED_CREDENTIAL_DATA = 0x40;
    private static final String NONCE_EXTENSION_OID = "1.2.840.113635.100.8.2";
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final CBORMapper CBOR_MAPPER = new CBORMapper();

    @Override
    public byte[] decodeBase64Url(String value) {
        return BASE64_URL_DECODER.decode(value);
    }

    @Override
    public byte[] sha256(byte[] input) throws GeneralSecurityException {
        return MessageDigest.getInstance("SHA-256").digest(input);
    }

    @Override
    public String base64UrlEncode(byte[] value) {
        return BASE64_URL_ENCODER.encodeToString(value);
    }

    @Override
    public ParsedAttestation parseAndVerifyAttestationObject(
            String attestationObjectB64,
            byte[] clientDataHash,
            String expectedKeyId
    ) throws GeneralSecurityException {
        try {
            byte[] rawAttestationObject = decodeBase64Url(attestationObjectB64);
            Map<Object, Object> attestation = CBOR_MAPPER.readValue(rawAttestationObject, new TypeReference<>() {
            });

            String format = asString(attestation.get("fmt"));
            if (!"apple-appattest".equals(format)) {
                throw new GeneralSecurityException("Unsupported attestation format: " + format);
            }

            byte[] authData = asByteArray(attestation.get("authData"));
            validateAuthenticatorDataForAttestation(authData);

            @SuppressWarnings("unchecked")
            Map<Object, Object> attStmt = (Map<Object, Object>) attestation.get("attStmt");
            if (attStmt == null) {
                throw new GeneralSecurityException("attStmt is missing");
            }
            @SuppressWarnings("unchecked")
            List<byte[]> x5c = (List<byte[]>) attStmt.get("x5c");
            if (x5c == null || x5c.size() < 2) {
                throw new GeneralSecurityException("x5c certificate chain is missing");
            }

            X509Certificate leaf = parseX509(x5c.getFirst());
            X509Certificate intermediate = parseX509(x5c.get(1));
            validateCertificateChain(leaf, intermediate);

            byte[] expectedNonce = sha256(concat(authData, clientDataHash));
            byte[] nonceFromCert = extractNonceFromCertificate(leaf);
            if (!constantTimeEquals(expectedNonce, nonceFromCert)) {
                throw new GeneralSecurityException("Certificate nonce does not match authData/clientDataHash");
            }

            ParsedAttestedCredential credential = parseAttestedCredentialData(authData);
            byte[] derivedKeyId = deriveKeyId(credential.uncompressedPublicKey());
            byte[] providedKeyId = decodeBase64Flexible(expectedKeyId);
            if (!constantTimeEquals(derivedKeyId, providedKeyId)) {
                throw new GeneralSecurityException("keyId does not match attested public key");
            }

            PublicKey publicKey = createEcPublicKey(credential.xCoord(), credential.yCoord());
            return new ParsedAttestation(publicKey, extractRpIdHash(authData), extractCounter(authData));
        } catch (GeneralSecurityException e) {
            throw e;
        } catch (Exception e) {
            throw new GeneralSecurityException("Invalid attestationObject: " + e.getMessage(), e);
        }
    }

    @Override
    public ParsedAssertion parseAssertionObject(String assertionObjectB64) {
        try {
            byte[] rawAssertionObject = decodeBase64Url(assertionObjectB64);
            Map<Object, Object> assertion = CBOR_MAPPER.readValue(rawAssertionObject, new TypeReference<>() {
            });

            byte[] authenticatorData = asByteArray(assertion.get("authenticatorData"));
            byte[] signature = asByteArray(assertion.get("signature"));
            if (authenticatorData.length < AUTH_DATA_MIN_LENGTH) {
                throw new IllegalArgumentException("authenticatorData is too short");
            }
            return new ParsedAssertion(
                    authenticatorData,
                    signature,
                    extractRpIdHash(authenticatorData),
                    extractCounter(authenticatorData)
            );
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid assertionObject: " + e.getMessage(), e);
        }
    }

    @Override
    public boolean verifyAssertionSignature(
            PublicKey publicKey,
            byte[] authData,
            byte[] clientDataHash,
            byte[] signature
    ) throws GeneralSecurityException {
        // Per Apple App Attest: nonce = SHA256(authenticatorData || clientDataHash); signature is ECDSA-SHA256 over nonce.
        byte[] nonce = sha256(concat(authData, clientDataHash));
        Signature verifier = Signature.getInstance("SHA256withECDSA");
        verifier.initVerify(publicKey);
        verifier.update(nonce);
        try {
            return verifier.verify(signature);
        } catch (java.security.SignatureException e) {
            return false;
        }
    }

    @Override
    public long extractCounter(byte[] authData) {
        if (authData.length < COUNTER_OFFSET + 4) {
            throw new IllegalArgumentException("Authenticator data is too short");
        }
        ByteBuffer bb = ByteBuffer.wrap(authData, COUNTER_OFFSET, 4);
        return Integer.toUnsignedLong(bb.getInt());
    }

    @Override
    public byte[] extractRpIdHash(byte[] authData) {
        if (authData.length < RP_ID_HASH_LENGTH) {
            throw new IllegalArgumentException("Authenticator data is too short");
        }
        byte[] rpIdHash = new byte[RP_ID_HASH_LENGTH];
        System.arraycopy(authData, 0, rpIdHash, 0, RP_ID_HASH_LENGTH);
        return rpIdHash;
    }

    @Override
    public boolean constantTimeEquals(byte[] left, byte[] right) {
        return MessageDigest.isEqual(left, right);
    }

    private void validateAuthenticatorDataForAttestation(byte[] authData) throws GeneralSecurityException {
        if (authData.length < AUTH_DATA_MIN_LENGTH) {
            throw new GeneralSecurityException("authData is too short");
        }
        int flags = authData[FLAG_OFFSET] & 0xFF;
        if ((flags & FLAG_ATTESTED_CREDENTIAL_DATA) == 0) {
            throw new GeneralSecurityException("Attested credential data flag is not set");
        }
    }

    private ParsedAttestedCredential parseAttestedCredentialData(byte[] authData) throws GeneralSecurityException {
        int offset = AUTH_DATA_MIN_LENGTH;
        if (authData.length < offset + 16 + 2) {
            throw new GeneralSecurityException("authData attested credential section is too short");
        }
        offset += 16;
        int credentialIdLength = ((authData[offset] & 0xFF) << 8) | (authData[offset + 1] & 0xFF);
        offset += 2;
        if (authData.length < offset + credentialIdLength) {
            throw new GeneralSecurityException("Credential ID length is invalid");
        }
        byte[] credentialId = new byte[credentialIdLength];
        System.arraycopy(authData, offset, credentialId, 0, credentialIdLength);
        offset += credentialIdLength;

        byte[] coseKeyBytes = new byte[authData.length - offset];
        System.arraycopy(authData, offset, coseKeyBytes, 0, coseKeyBytes.length);
        Map<Object, Object> coseKey;
        try {
            coseKey = CBOR_MAPPER.readValue(coseKeyBytes, new TypeReference<>() {
            });
        } catch (Exception e) {
            throw new GeneralSecurityException("Invalid COSE key data", e);
        }

        byte[] x = coseCoordinate(coseKey, -2);
        byte[] y = coseCoordinate(coseKey, -3);
        if (x.length != 32 || y.length != 32) {
            throw new GeneralSecurityException("Unexpected EC key coordinate size");
        }
        return new ParsedAttestedCredential(credentialId, x, y);
    }

    private byte[] coseCoordinate(Map<Object, Object> coseKey, int label) throws GeneralSecurityException {
        for (Map.Entry<Object, Object> entry : coseKey.entrySet()) {
            if (isCoseLabel(entry.getKey(), label)) {
                return asByteArray(entry.getValue());
            }
        }
        throw new GeneralSecurityException("COSE key missing coordinate label " + label);
    }

    private boolean isCoseLabel(Object key, int expectedLabel) {
        if (key instanceof Number number) {
            return number.intValue() == expectedLabel;
        }
        if (key instanceof String s) {
            try {
                return Integer.parseInt(s) == expectedLabel;
            } catch (NumberFormatException ignored) {
                return false;
            }
        }
        return false;
    }

    private byte[] deriveKeyId(byte[] uncompressedPublicKey) throws GeneralSecurityException {
        return sha256(uncompressedPublicKey);
    }

    private byte[] decodeBase64Flexible(String value) throws GeneralSecurityException {
        if (value == null || value.isBlank()) {
            throw new GeneralSecurityException("keyId is missing");
        }
        String normalized = value.trim();
        try {
            return Base64.getUrlDecoder().decode(padToMultipleOf4(normalized));
        } catch (IllegalArgumentException ignored) {
            try {
                return Base64.getDecoder().decode(padToMultipleOf4(normalized));
            } catch (IllegalArgumentException e) {
                throw new GeneralSecurityException("Invalid keyId encoding", e);
            }
        }
    }

    private String padToMultipleOf4(String value) {
        int remainder = value.length() % 4;
        if (remainder == 0) {
            return value;
        }
        return value + "=".repeat(4 - remainder);
    }

    private PublicKey createEcPublicKey(byte[] xCoord, byte[] yCoord) throws GeneralSecurityException {
        try {
            AlgorithmParameters parameters = AlgorithmParameters.getInstance("EC");
            parameters.init(new ECGenParameterSpec("secp256r1"));
            ECParameterSpec ecParameters = parameters.getParameterSpec(ECParameterSpec.class);
            java.security.spec.ECPoint point = new java.security.spec.ECPoint(
                    new BigInteger(1, xCoord),
                    new BigInteger(1, yCoord)
            );
            return KeyFactory.getInstance("EC").generatePublic(new ECPublicKeySpec(point, ecParameters));
        } catch (InvalidKeySpecException e) {
            throw new GeneralSecurityException("Unable to build EC public key", e);
        }
    }

    private void validateCertificateChain(X509Certificate leaf, X509Certificate intermediate) throws GeneralSecurityException {
        try {
            leaf.checkValidity();
            intermediate.checkValidity();
            leaf.verify(intermediate.getPublicKey());

            CertPath certPath = CertificateFactory.getInstance("X.509").generateCertPath(List.of(leaf, intermediate));
            CertPathValidator validator = CertPathValidator.getInstance("PKIX");
            PKIXParameters pkix = new PKIXParameters(Set.of(new TrustAnchor(appleAppAttestationRootCA(), null)));
            pkix.setRevocationEnabled(false);
            validator.validate(certPath, pkix);
        } catch (GeneralSecurityException e) {
            throw new GeneralSecurityException("Invalid attestation certificate chain: " + e.getMessage(), e);
        }
    }

    private X509Certificate parseX509(byte[] der) throws GeneralSecurityException {
        try {
            return (X509Certificate) CertificateFactory.getInstance("X.509")
                    .generateCertificate(new java.io.ByteArrayInputStream(der));
        } catch (Exception e) {
            throw new GeneralSecurityException("Invalid X509 certificate", e);
        }
    }

    private byte[] extractNonceFromCertificate(X509Certificate certificate) throws GeneralSecurityException {
        byte[] extension = certificate.getExtensionValue(NONCE_EXTENSION_OID);
        if (extension == null) {
            throw new GeneralSecurityException("Nonce extension is missing in attestation certificate");
        }
        try {
            ASN1OctetString outerOctet = ASN1OctetString.getInstance(extension);
            ASN1Primitive inner = ASN1Primitive.fromByteArray(outerOctet.getOctets());
            byte[] nonce = findNonceOctets(inner);
            if (nonce == null) {
                throw new GeneralSecurityException("Nonce extension does not contain an OCTET STRING nonce");
            }
            return nonce;
        } catch (Exception e) {
            throw new GeneralSecurityException("Unable to parse nonce extension", e);
        }
    }

    private byte[] findNonceOctets(ASN1Encodable node) {
        if (node instanceof ASN1OctetString octet) {
            byte[] value = octet.getOctets();
            if (value.length == 32) {
                return value;
            }
            try {
                ASN1Primitive nested = ASN1Primitive.fromByteArray(value);
                byte[] nestedResult = findNonceOctets(nested);
                if (nestedResult != null) {
                    return nestedResult;
                }
            } catch (Exception ignored) {
            }
            return null;
        }
        if (node instanceof ASN1Sequence sequence) {
            for (ASN1Encodable child : sequence) {
                byte[] result = findNonceOctets(child);
                if (result != null) {
                    return result;
                }
            }
            return null;
        }
        if (node instanceof ASN1Set set) {
            for (ASN1Encodable child : set) {
                byte[] result = findNonceOctets(child);
                if (result != null) {
                    return result;
                }
            }
            return null;
        }
        if (node instanceof ASN1TaggedObject tagged) {
            return findNonceOctets(tagged.getBaseObject());
        }
        return null;
    }

    private X509Certificate appleAppAttestationRootCA() throws GeneralSecurityException {
        byte[] der = Base64.getMimeDecoder().decode(
                APPLE_APP_ATTESTATION_ROOT_CA_PEM
                        .replace("-----BEGIN CERTIFICATE-----", "")
                        .replace("-----END CERTIFICATE-----", "")
                        .trim()
        );
        return parseX509(der);
    }

    private String asString(Object value) {
        if (value == null) {
            return "";
        }
        if (value instanceof String s) {
            return s;
        }
        return String.valueOf(value);
    }

    private byte[] asByteArray(Object value) {
        if (value instanceof byte[] bytes) {
            return bytes;
        }
        if (value == null) {
            throw new IllegalArgumentException("Expected byte[] value but found null");
        }
        throw new IllegalArgumentException("Expected byte[] value but found " + value.getClass().getSimpleName());
    }

    private byte[] concat(byte[] left, byte[] right) {
        byte[] result = new byte[left.length + right.length];
        System.arraycopy(left, 0, result, 0, left.length);
        System.arraycopy(right, 0, result, left.length, right.length);
        return result;
    }

    private record ParsedAttestedCredential(byte[] credentialId, byte[] xCoord, byte[] yCoord) {
        byte[] uncompressedPublicKey() {
            byte[] key = new byte[65];
            key[0] = 0x04;
            System.arraycopy(xCoord, 0, key, 1, 32);
            System.arraycopy(yCoord, 0, key, 33, 32);
            return key;
        }
    }
}
