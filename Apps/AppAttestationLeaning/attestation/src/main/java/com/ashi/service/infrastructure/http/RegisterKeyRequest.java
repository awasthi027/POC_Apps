package com.ashi.service.infrastructure.http;

public record RegisterKeyRequest(
        String keyId,
        String challenge,
        String clientDataHash,
        String attestationObject
) {
}
