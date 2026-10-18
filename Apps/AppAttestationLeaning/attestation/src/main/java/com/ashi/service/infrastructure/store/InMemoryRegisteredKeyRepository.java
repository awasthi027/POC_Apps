package com.ashi.service.infrastructure.store;

import com.ashi.service.application.port.RegisteredKeyRepository;
import com.ashi.service.domain.RegisteredKey;

import java.util.concurrent.ConcurrentHashMap;

public final class InMemoryRegisteredKeyRepository implements RegisteredKeyRepository {
    private final ConcurrentHashMap<String, RegisteredKey> keys = new ConcurrentHashMap<>();

    @Override
    public RegisteredKey findByKeyId(String keyId) {
        return keys.get(keyId);
    }

    @Override
    public void save(String keyId, RegisteredKey registeredKey) {
        keys.put(keyId, registeredKey);
    }
}
