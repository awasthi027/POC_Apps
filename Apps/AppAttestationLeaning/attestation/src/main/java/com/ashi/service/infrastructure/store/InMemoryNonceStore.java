package com.ashi.service.infrastructure.store;

import com.ashi.service.application.port.NonceStore;

import java.util.concurrent.ConcurrentHashMap;

public final class InMemoryNonceStore implements NonceStore {
    private final ConcurrentHashMap<String, Long> nonceCache = new ConcurrentHashMap<>();
    private final long nonceRetentionMs;

    public InMemoryNonceStore(long nonceRetentionMs) {
        this.nonceRetentionMs = nonceRetentionMs;
    }

    @Override
    public boolean isReplay(String keyId, String nonce, long now) {
        evictExpired(now);
        String nonceKey = keyId + ":" + nonce;
        Long previous = nonceCache.putIfAbsent(nonceKey, now);
        return previous != null;
    }

    private void evictExpired(long now) {
        nonceCache.entrySet().removeIf(entry -> now - entry.getValue() > nonceRetentionMs);
    }
}
