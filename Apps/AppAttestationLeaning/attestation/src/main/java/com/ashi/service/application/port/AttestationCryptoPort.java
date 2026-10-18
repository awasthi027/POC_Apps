package com.ashi.service.application.port;

import java.security.GeneralSecurityException;
import java.security.PublicKey;

public interface AttestationCryptoPort {
    record ParsedAttestation(
            PublicKey publicKey,
            byte[] rpIdHash,
            long signCount
    ) {
    }

    record ParsedAssertion(
            byte[] authenticatorData,
            byte[] signature,
            byte[] rpIdHash,
            long signCount
    ) {
    }

    byte[] decodeBase64Url(String value);

    byte[] sha256(byte[] input) throws GeneralSecurityException;

    String base64UrlEncode(byte[] value);

    ParsedAttestation parseAndVerifyAttestationObject(
            String attestationObjectB64,
            byte[] clientDataHash,
            String expectedKeyId
    ) throws GeneralSecurityException;

    ParsedAssertion parseAssertionObject(String assertionObjectB64);

    boolean verifyAssertionSignature(
            PublicKey publicKey,
            byte[] authData,
            byte[] clientDataHash,
            byte[] signature
    ) throws GeneralSecurityException;

    long extractCounter(byte[] authData);

    byte[] extractRpIdHash(byte[] authData);

    boolean constantTimeEquals(byte[] left, byte[] right);
}
