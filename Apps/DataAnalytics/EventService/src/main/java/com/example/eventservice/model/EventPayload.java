package com.example.eventservice.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.time.Instant;
import java.util.Map;

/**
 * One event as sent by the SDK. JSON names are snake_case (event_id, event_name ...).
 * The aliases also accept the field names of the SimpleAnalytics client (id, name, time, sessionID, userID).
 * Fields we do not know are ignored, so newer SDKs do not break this service.
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record EventPayload(
        @JsonAlias({"id", "eventId"}) String eventId,
        @JsonAlias({"name", "eventName"}) String eventName,
        @JsonAlias({"time"}) Instant timestamp,
        @JsonAlias({"sessionID", "sessionId"}) String sessionId,
        @JsonAlias({"anonymousID", "anonymousId"}) String anonymousId,
        @JsonAlias({"userID", "userId"}) String userId,
        Map<String, Object> properties,
        Map<String, Object> context,
        Integer schemaVersion) {
}
