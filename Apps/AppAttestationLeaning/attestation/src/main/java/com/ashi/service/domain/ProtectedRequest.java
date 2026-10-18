package com.ashi.service.domain;

public record ProtectedRequest(
        String method,
        String path,
        byte[] body,
        String keyId,
        String assertionObjectB64,
        String clientDataHashB64,
        String timestampRaw,
        String nonce
) {
}
