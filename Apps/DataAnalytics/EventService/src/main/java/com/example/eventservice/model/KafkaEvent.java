package com.example.eventservice.model;

import java.time.Instant;

/** The message stored in Kafka: the event plus the project and the time we accepted it. */
public record KafkaEvent(String projectId, Instant receivedAt, EventPayload event) {
}
