package com.ashi.service.application;

import com.ashi.service.application.port.AttestationCryptoPort;
import com.ashi.service.application.port.NonceStore;
import com.ashi.service.application.port.RegisteredKeyRepository;
import com.ashi.service.domain.ProtectedRequest;
import com.ashi.service.domain.RegisteredKey;
import com.ashi.service.domain.VerificationResult;

import java.security.GeneralSecurityException;
import java.util.Base64;

public final class AttestationService {
    private final RegisteredKeyRepository keyRepository;
    private final NonceStore nonceStore;
    private final AttestationCryptoPort crypto;
    private final long allowedClockSkewMs;
    private final byte[] expectedAppIdHash;

    public AttestationService(
            RegisteredKeyRepository keyRepository,
            NonceStore nonceStore,
            AttestationCryptoPort crypto,
            long allowedClockSkewMs,
            String appId
    ) throws GeneralSecurityException {
        this.keyRepository = keyRepository;
        this.nonceStore = nonceStore;
        this.crypto = crypto;
        this.allowedClockSkewMs = allowedClockSkewMs;
        this.expectedAppIdHash = crypto.sha256(appId.getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    public void registerKey(
            String keyId,
            String challengeB64,
            String clientDataHashB64,
            String attestationObjectB64
    ) throws GeneralSecurityException {
        String normalizedKeyId = normalizeKeyId(keyId);
        byte[] clientDataHash = crypto.decodeBase64Url(clientDataHashB64);
        if (!isBlank(challengeB64)) {
            byte[] challenge = crypto.decodeBase64Url(challengeB64);
            byte[] expectedHash = crypto.sha256(challenge);
            if (!crypto.constantTimeEquals(expectedHash, clientDataHash)) {
                throw new GeneralSecurityException("clientDataHash does not match challenge");
            }
        }

        AttestationCryptoPort.ParsedAttestation parsed = crypto.parseAndVerifyAttestationObject(
                attestationObjectB64,
                clientDataHash,
                keyId
        );
        if (!crypto.constantTimeEquals(parsed.rpIdHash(), expectedAppIdHash)) {
            throw new GeneralSecurityException("Attestation rpIdHash does not match app identifier");
        }
        RegisteredKey registeredKey = new RegisteredKey(parsed.publicKey(), parsed.rpIdHash());
        registeredKey.assertionCounter(parsed.signCount());
        keyRepository.save(normalizedKeyId, registeredKey);
    }

    public VerificationResult verifyProtectedRequest(ProtectedRequest request) {
        try {
            if (isBlank(request.keyId()) || isBlank(request.assertionObjectB64())
                    || isBlank(request.clientDataHashB64()) || isBlank(request.timestampRaw()) || isBlank(request.nonce())) {
                return VerificationResult.fail("Missing required attestation headers");
            }
            String normalizedKeyId = normalizeKeyId(request.keyId());

            RegisteredKey registeredKey = keyRepository.findByKeyId(normalizedKeyId);
            if (registeredKey == null) {
                return VerificationResult.fail("Unknown keyId");
            }

            long timestamp = Long.parseLong(request.timestampRaw());
            long now = System.currentTimeMillis();
            if (Math.abs(now - timestamp) > allowedClockSkewMs) {
                return VerificationResult.fail("Request freshness check failed");
            }

            if (nonceStore.isReplay(normalizedKeyId, request.nonce(), now)) {
                return VerificationResult.fail("Nonce replay detected");
            }

            byte[] providedClientDataHash = crypto.decodeBase64Url(request.clientDataHashB64());
            byte[] expectedClientDataHash = crypto.sha256(canonicalBinding(
                    request.method(),
                    request.path(),
                    request.body(),
                    timestamp,
                    request.nonce(),
                    request.keyId()
            ).getBytes(java.nio.charset.StandardCharsets.UTF_8));

            if (!crypto.constantTimeEquals(providedClientDataHash, expectedClientDataHash)) {
                return VerificationResult.fail("Request binding check failed");
            }

            AttestationCryptoPort.ParsedAssertion parsedAssertion = crypto.parseAssertionObject(request.assertionObjectB64());
            if (!crypto.constantTimeEquals(parsedAssertion.rpIdHash(), registeredKey.rpIdHash())) {
                return VerificationResult.fail("Assertion rpIdHash does not match registered app");
            }

            boolean signatureValid = crypto.verifyAssertionSignature(
                    registeredKey.publicKey(),
                    parsedAssertion.authenticatorData(),
                    expectedClientDataHash,
                    parsedAssertion.signature()
            );
            if (!signatureValid) {
                return VerificationResult.fail("Assertion signature verification failed");
            }

            synchronized (registeredKey.lock()) {
                if (parsedAssertion.signCount() <= registeredKey.assertionCounter()) {
                    return VerificationResult.fail("Out-of-order or replayed assertion counter");
                }
                registeredKey.assertionCounter(parsedAssertion.signCount());
            }
            return VerificationResult.pass();
        } catch (NumberFormatException e) {
            return VerificationResult.fail("Invalid timestamp format");
        } catch (IllegalArgumentException e) {
            return VerificationResult.fail("Invalid base64url encoding in attestation headers");
        } catch (GeneralSecurityException e) {
            return VerificationResult.fail("Cryptographic verification error: " + e.getMessage());
        }
    }

    private String canonicalBinding(
            String method,
            String path,
            byte[] body,
            long timestamp,
            String nonce,
            String keyId
    ) {
        String bodyHashB64 = crypto.base64UrlEncode(sha256Unchecked(body));
        return String.join("\n",
                method.toUpperCase(),
                path,
                bodyHashB64,
                String.valueOf(timestamp),
                nonce,
                keyId
        );
    }

    private byte[] sha256Unchecked(byte[] input) {
        try {
            return crypto.sha256(input);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private String normalizeKeyId(String keyId) {
        byte[] rawKeyId = decodeKeyIdFlexible(keyId);
        return crypto.base64UrlEncode(rawKeyId);
    }

    private byte[] decodeKeyIdFlexible(String value) {
        if (isBlank(value)) {
            throw new IllegalArgumentException("keyId is required");
        }
        String normalized = value.trim();
        try {
            return Base64.getUrlDecoder().decode(padToMultipleOf4(normalized));
        } catch (IllegalArgumentException ignored) {
            return Base64.getDecoder().decode(padToMultipleOf4(normalized));
        }
    }

    private String padToMultipleOf4(String value) {
        int remainder = value.length() % 4;
        if (remainder == 0) {
            return value;
        }
        return value + "=".repeat(4 - remainder);
    }
}
