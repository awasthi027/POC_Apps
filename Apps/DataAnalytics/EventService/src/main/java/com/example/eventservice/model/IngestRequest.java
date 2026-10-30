package com.example.eventservice.model;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

/** The body of POST /v1/analytics/events. */
@JsonIgnoreProperties(ignoreUnknown = true)
public record IngestRequest(
        @JsonAlias({"projectID", "projectId"}) String projectId,
        String batchId,
        String sdkVersion,
        List<EventPayload> events) {
}
