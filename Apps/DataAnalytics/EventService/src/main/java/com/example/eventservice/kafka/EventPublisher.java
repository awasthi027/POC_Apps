package com.example.eventservice.kafka;

import com.example.eventservice.model.EventPayload;
import com.example.eventservice.model.KafkaEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.concurrent.CompletableFuture;

/** Writes events to Kafka. */
@Component
public class EventPublisher {

    private final KafkaTemplate<String, String> kafka;
    private final ObjectMapper mapper;
    private final String topic;

    public EventPublisher(KafkaTemplate<String, String> kafka, ObjectMapper mapper,
                          @Value("${analytics.topic}") String topic) {
        this.kafka = kafka;
        this.mapper = mapper;
        this.topic = topic;
    }

    /**
     * The returned future completes when Kafka has the event on disk on all in-sync replicas (acks=all).
     * Only then may we tell the SDK "accepted".
     */
    public CompletableFuture<?> publish(String projectId, EventPayload event) {
        try {
            String json = mapper.writeValueAsString(new KafkaEvent(projectId, Instant.now(), event));
            return kafka.send(topic, keyFor(projectId, event), json);
        } catch (JsonProcessingException | RuntimeException e) {
            return CompletableFuture.failedFuture(e);
        }
    }

    /** Same user = same key = same partition, so one user's events stay in order. */
    private static String keyFor(String projectId, EventPayload event) {
        String who = firstNotBlank(event.userId(), event.anonymousId(), event.eventId());
        return projectId + ":" + who;
    }

    private static String firstNotBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) return v;
        }
        return "";
    }
}
