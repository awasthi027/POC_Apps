package com.ashi.service.config;

import com.ashi.service.application.AttestationService;
import com.ashi.service.application.port.AttestationCryptoPort;
import com.ashi.service.application.port.NonceStore;
import com.ashi.service.application.port.RegisteredKeyRepository;
import com.ashi.service.infrastructure.crypto.AttestationCrypto;
import com.ashi.service.infrastructure.store.InMemoryNonceStore;
import com.ashi.service.infrastructure.store.InMemoryRegisteredKeyRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.security.GeneralSecurityException;

@Configuration
public class AttestationBeanConfig {
    @Bean
    public RegisteredKeyRepository registeredKeyRepository() {
        return new InMemoryRegisteredKeyRepository();
    }

    @Bean
    public NonceStore nonceStore(
            @Value("${app.attestation.nonce-retention-ms:600000}") long nonceRetentionMs
    ) {
        return new InMemoryNonceStore(nonceRetentionMs);
    }

    @Bean
    public AttestationCryptoPort attestationCrypto() {
        return new AttestationCrypto();
    }

    @Bean
    public AttestationService attestationService(
            RegisteredKeyRepository keyRepository,
            NonceStore nonceStore,
            AttestationCryptoPort crypto,
            @Value("${app.attestation.allowed-clock-skew-ms:120000}") long allowedClockSkewMs,
            @Value("${app.attestation.team-id}") String teamId,
            @Value("${app.attestation.bundle-id}") String bundleId
    ) throws GeneralSecurityException {
        String appId = teamId + "." + bundleId;
        return new AttestationService(
                keyRepository,
                nonceStore,
                crypto,
                allowedClockSkewMs,
                appId
        );
    }
}
