package com.ashi.service.domain;

import java.security.PublicKey;

public final class RegisteredKey {
    private final PublicKey publicKey;
    private final byte[] rpIdHash;
    private final Object lock = new Object();
    private long assertionCounter = -1L;

    public RegisteredKey(PublicKey publicKey, byte[] rpIdHash) {
        this.publicKey = publicKey;
        this.rpIdHash = rpIdHash.clone();
    }

    public PublicKey publicKey() {
        return publicKey;
    }

    public byte[] rpIdHash() {
        return rpIdHash.clone();
    }

    public Object lock() {
        return lock;
    }

    public long assertionCounter() {
        return assertionCounter;
    }

    public void assertionCounter(long assertionCounter) {
        this.assertionCounter = assertionCounter;
    }
}
