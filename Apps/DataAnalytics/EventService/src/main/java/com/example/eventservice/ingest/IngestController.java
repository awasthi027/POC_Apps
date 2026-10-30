package com.example.eventservice.ingest;

import com.example.eventservice.model.IngestRequest;
import com.example.eventservice.model.IngestResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RestController;

import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;

/** The endpoint the SDK uploads to. See BACKEND_CONTRACT.md. */
@RestController
public class IngestController {

    private final IngestService service;
    private final String ingestToken;

    public IngestController(IngestService service, @Value("${analytics.ingest-token:}") String ingestToken) {
        this.service = service;
        this.ingestToken = ingestToken;
    }

    @PostMapping("/v1/analytics/events")
    public ResponseEntity<IngestResponse> ingest(@RequestHeader(value = "Authorization", required = false) String authorization,
                                                 @RequestBody IngestRequest request) {
        if (!isAuthorized(authorization)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();   // the SDK pauses uploads on 401
        }
        return ResponseEntity.ok(service.ingest(request));
    }

    private boolean isAuthorized(String authorization) {
        if (ingestToken.isBlank()) return true;                                // auth turned off (local development)
        if (authorization == null) return false;
        return MessageDigest.isEqual(                                          // constant-time compare
                authorization.getBytes(StandardCharsets.UTF_8),
                ("Bearer " + ingestToken).getBytes(StandardCharsets.UTF_8));
    }

    @ExceptionHandler(IngestService.BadBatchException.class)
    ResponseEntity<String> badBatch(IngestService.BadBatchException e) {
        return ResponseEntity.badRequest().body(e.getMessage());
    }

    @ExceptionHandler(IngestService.KafkaUnavailableException.class)
    ResponseEntity<Void> kafkaDown() {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).header("Retry-After", "5").build();
    }
}
