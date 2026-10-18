package com.ashi.service.application.port;

public interface NonceStore {
    boolean isReplay(String keyId, String nonce, long now);
}
