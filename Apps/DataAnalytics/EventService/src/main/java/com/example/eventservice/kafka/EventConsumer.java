package com.example.eventservice.kafka;

import com.example.eventservice.model.KafkaEvent;
import com.example.eventservice.persistence.EventRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.TransientDataAccessException;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

/**
 * Reads events from Kafka and stores them in Postgres.
 *
 * Kafka commits the offsets only after this method returns. If it throws, Kafka delivers the same batch again.
 * That is safe because the insert ignores events that are already stored (same project_id + event_id).
 */
@Component
public class EventConsumer {

    private static final Logger log = LoggerFactory.getLogger(EventConsumer.class);

    private final EventRepository repository;
    private final ObjectMapper mapper;
    private final KafkaTemplate<String, String> kafka;
    private final String deadLetterTopic;

    public EventConsumer(EventRepository repository, ObjectMapper mapper, KafkaTemplate<String, String> kafka,
                         @Value("${analytics.topic}") String topic) {
        this.repository = repository;
        this.mapper = mapper;
        this.kafka = kafka;
        this.deadLetterTopic = topic + ".dlt";
    }

    @KafkaListener(topics = "${analytics.topic}", batch = "true")
    public void consume(List<String> messages) {
        List<KafkaEvent> events = new ArrayList<>();
        List<String> raw = new ArrayList<>();
        for (String message : messages) {
            try {
                events.add(mapper.readValue(message, KafkaEvent.class));
                raw.add(message);
            } catch (Exception e) {
                deadLetter(message, "cannot read JSON");
            }
        }
        if (events.isEmpty()) return;

        try {
            int inserted = repository.insertBatch(events);
            log.debug("stored {} of {} events (the rest were already stored)", inserted, events.size());
        } catch (DataAccessException e) {
            if (isTemporary(e)) throw e;          // database down: retry the whole batch later
            storeOneByOne(events, raw);           // one bad row must not block the others
        }
    }

    private void storeOneByOne(List<KafkaEvent> events, List<String> raw) {
        for (int i = 0; i < events.size(); i++) {
            try {
                repository.insertBatch(List.of(events.get(i)));
            } catch (DataAccessException e) {
                if (isTemporary(e)) throw e;
                deadLetter(raw.get(i), "database refused the row");
            }
        }
    }

    private static boolean isTemporary(DataAccessException e) {
        return e instanceof TransientDataAccessException
                || e instanceof DataAccessResourceFailureException
                || e instanceof CannotGetJdbcConnectionException;
    }

    private void deadLetter(String message, String reason) {
        log.warn("moving a message to {}: {}", deadLetterTopic, reason);   // never log the message itself
        kafka.send(deadLetterTopic, message);
    }
}
