package com.ashi.service.application.port;

import com.ashi.service.domain.RegisteredKey;

public interface RegisteredKeyRepository {
    RegisteredKey findByKeyId(String keyId);

    void save(String keyId, RegisteredKey registeredKey);
}
