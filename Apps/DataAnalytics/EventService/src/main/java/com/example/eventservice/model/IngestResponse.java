package com.example.eventservice.model;

import java.util.List;

/**
 * The acknowledgment the SDK relies on. The SDK deletes ONLY the events listed in
 * acceptedEventIds / duplicateEventIds / non-retryable rejectedEvents.
 */
public record IngestResponse(
        String batchId,
        List<String> acceptedEventIds,
        List<String> duplicateEventIds,
        List<Rejection> rejectedEvents) {

    public record Rejection(String eventId, String reason, boolean retryable) {
    }
}
