package com.ashi.service.infrastructure.http;

import com.ashi.service.application.AttestationService;
import com.ashi.service.domain.ProtectedRequest;
import com.ashi.service.domain.VerificationResult;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.security.GeneralSecurityException;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Map;

@RestController
public final class AttestationController {
    private static final Logger log = LoggerFactory.getLogger(AttestationController.class);
    private static final String HEADER_KEY_ID = "X-AppAttest-Key-Id";
    private static final String HEADER_ASSERTION = "X-AppAttest-Assertion";
    private static final String HEADER_CLIENT_DATA_HASH = "X-AppAttest-Client-Data-Hash";
    private static final String HEADER_TIMESTAMP = "X-AppAttest-Timestamp";
    private static final String HEADER_NONCE = "X-AppAttest-Nonce";

    private final AttestationService attestationService;

    public AttestationController(AttestationService attestationService) {
        this.attestationService = attestationService;
    }

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of("status", "ok", "time", Instant.now().toString());
    }

    @PostMapping("/attestation/register")
    public ResponseEntity<?> registerKey(@RequestBody(required = false) RegisterKeyRequest request) {
        String keyId = request == null ? "" : trim(request.keyId());
        String challenge = request == null ? "" : trim(request.challenge());
        String clientDataHash = request == null ? "" : trim(request.clientDataHash());
        String attestationObject = request == null ? "" : trim(request.attestationObject());
        log.info("Received /attestation/register request for keyId={}", keyId);
        if (isBlank(keyId) || isBlank(clientDataHash) || isBlank(attestationObject)) {
            log.warn("Register request rejected: missing keyId/clientDataHash/attestationObject");
            return ResponseEntity.badRequest().body(
                    new AttestationErrorResponse("keyId, clientDataHash and attestationObject are required")
            );
        }

        try {
            attestationService.registerKey(keyId, challenge, clientDataHash, attestationObject);
            log.info("Register request succeeded for keyId={}", keyId);
            return ResponseEntity.status(HttpStatus.CREATED).body(new RegisterKeyResponse("registered", keyId));
        } catch (GeneralSecurityException e) {
            log.warn("Register request failed for keyId={}: {}", keyId, e.getMessage());
            return ResponseEntity.badRequest().body(new AttestationErrorResponse("Invalid App Attest payload: " + e.getMessage()));
        }
    }

    @GetMapping("/protected/profile")
    public ResponseEntity<?> protectedProfile(
            @RequestHeader(value = HEADER_KEY_ID, required = false) String keyId,
            @RequestHeader(value = HEADER_ASSERTION, required = false) String assertionObjectB64,
            @RequestHeader(value = HEADER_CLIENT_DATA_HASH, required = false) String clientDataHashB64,
            @RequestHeader(value = HEADER_TIMESTAMP, required = false) String timestampRaw,
            @RequestHeader(value = HEADER_NONCE, required = false) String nonce,
            HttpServletRequest httpRequest
    ) {
        log.info("Received {} {}", httpRequest.getMethod(), httpRequest.getRequestURI());
        ProtectedRequest protectedRequest = new ProtectedRequest(
                httpRequest.getMethod(),
                httpRequest.getRequestURI(),
                new byte[0],
                trim(keyId),
                trim(assertionObjectB64),
                trim(clientDataHashB64),
                trim(timestampRaw),
                trim(nonce)
        );

        VerificationResult result = attestationService.verifyProtectedRequest(protectedRequest);
        if (!result.valid()) {
            log.warn("Protected request rejected: {}", result.message());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new AttestationErrorResponse(result.message()));
        }

        return ResponseEntity.ok(Map.of(
                "status", "accepted",
                "message", "Request came from a verified app instance",
                "serverTime", Instant.now().toString()
        ));
    }

    @PostMapping("/protected/echo")
    public ResponseEntity<?> protectedEcho(
            @RequestHeader(value = HEADER_KEY_ID, required = false) String keyId,
            @RequestHeader(value = HEADER_ASSERTION, required = false) String assertionObjectB64,
            @RequestHeader(value = HEADER_CLIENT_DATA_HASH, required = false) String clientDataHashB64,
            @RequestHeader(value = HEADER_TIMESTAMP, required = false) String timestampRaw,
            @RequestHeader(value = HEADER_NONCE, required = false) String nonce,
            @RequestBody(required = false) byte[] requestBody,
            HttpServletRequest httpRequest
    ) {
        log.info("Received {} {}", httpRequest.getMethod(), httpRequest.getRequestURI());
        byte[] body = requestBody == null ? new byte[0] : requestBody;
        ProtectedRequest protectedRequest = new ProtectedRequest(
                httpRequest.getMethod(),
                httpRequest.getRequestURI(),
                body,
                trim(keyId),
                trim(assertionObjectB64),
                trim(clientDataHashB64),
                trim(timestampRaw),
                trim(nonce)
        );

        VerificationResult result = attestationService.verifyProtectedRequest(protectedRequest);
        if (!result.valid()) {
            log.warn("Protected request rejected: {}", result.message());
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new AttestationErrorResponse(result.message()));
        }

        return ResponseEntity.ok(new ProtectedEchoResponse(
                "accepted",
                "Request came from a verified app instance",
                httpRequest.getMethod(),
                httpRequest.getRequestURI(),
                new String(body, StandardCharsets.UTF_8)
        ));
    }

    private static String trim(String value) {
        if (value == null) {
            return "";
        }
        return value.trim();
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
