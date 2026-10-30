package com.example.eventservice.ingest;

import com.example.eventservice.kafka.EventPublisher;
import com.example.eventservice.model.EventPayload;
import com.example.eventservice.model.IngestRequest;
import com.example.eventservice.model.IngestResponse;
import com.example.eventservice.model.IngestResponse.Rejection;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;

/**
 * Validates a batch and writes every good event to Kafka.
 *
 * An event is called "accepted" only after Kafka confirmed it. The database insert (and the removal of
 * duplicates) happens later in the consumer; that is safe because Kafka keeps the event until it is stored.
 */
@Service
public class IngestService {

    private static final Logger log = LoggerFactory.getLogger(IngestService.class);
    private static final int MAX_EVENTS_PER_BATCH = 500;
    private static final int MAX_PROPERTIES = 100;

    private final EventPublisher publisher;

    public IngestService(EventPublisher publisher) {
        this.publisher = publisher;
    }

    /** @throws BadBatchException the request itself is unusable (HTTP 400)
     *  @throws KafkaUnavailableException Kafka did not confirm (HTTP 503, the SDK will retry) */
    public IngestResponse ingest(IngestRequest request) {
        if (request.projectId() == null || request.projectId().isBlank()) throw new BadBatchException("project_id is required");
        if (request.events() == null || request.events().isEmpty()) throw new BadBatchException("events is empty");
        if (request.events().size() > MAX_EVENTS_PER_BATCH) throw new BadBatchException("too many events in one batch");

        List<Rejection> rejected = new ArrayList<>();
        Map<String, CompletableFuture<?>> sent = new LinkedHashMap<>();

        for (EventPayload event : request.events()) {
            String problem = validate(event);
            if (problem != null) {
                // Not retryable: the same event would be refused again, so the SDK should drop it.
                rejected.add(new Rejection(event == null ? null : event.eventId(), problem, false));
            } else if (!sent.containsKey(event.eventId())) {      // the same id twice in one batch: send it once
                sent.put(event.eventId(), publisher.publish(request.projectId(), event));
            }
        }

        waitForKafka(sent);
        return new IngestResponse(request.batchId(), new ArrayList<>(sent.keySet()), List.of(), rejected);
    }

    private void waitForKafka(Map<String, CompletableFuture<?>> sent) {
        try {
            CompletableFuture.allOf(sent.values().toArray(new CompletableFuture[0])).get(10, TimeUnit.SECONDS);
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            log.warn("kafka did not confirm the batch: {}", e.toString());
            // Some events may already be in Kafka. That is fine: the SDK sends the batch again with the same
            // event ids and the database ignores the repeats.
            throw new KafkaUnavailableException(e);
        }
    }

    private static String validate(EventPayload e) {
        if (e == null) return "empty_event";
        if (e.eventId() == null || e.eventId().isBlank()) return "missing_event_id";
        if (e.eventName() == null || e.eventName().isBlank() || e.eventName().length() > 128) return "invalid_event_name";
        if (e.timestamp() == null) return "missing_timestamp";
        if (e.properties() != null && e.properties().size() > MAX_PROPERTIES) return "too_many_properties";
        return null;
    }

    public static class BadBatchException extends RuntimeException {
        public BadBatchException(String message) { super(message); }
    }

    public static class KafkaUnavailableException extends RuntimeException {
        public KafkaUnavailableException(Throwable cause) { super(cause); }
    }
}
