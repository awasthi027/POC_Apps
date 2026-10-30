package com.example.eventservice.persistence;

import com.example.eventservice.model.EventPayload;
import com.example.eventservice.model.KafkaEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Types;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;

/** Saves events in Postgres. */
@Repository
public class EventRepository {

    // ON CONFLICT DO NOTHING: inserting an event that is already stored is not an error and changes nothing.
    private static final String INSERT = """
            INSERT INTO events (project_id, event_id, event_name, event_time, received_at,
                                session_id, anonymous_id, user_id, properties, context, schema_version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb, ?::jsonb, ?)
            ON CONFLICT (project_id, event_id) DO NOTHING
            """;

    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;

    public EventRepository(JdbcTemplate jdbc, ObjectMapper mapper) {
        this.jdbc = jdbc;
        this.mapper = mapper;
    }

    /** Returns how many rows were new. */
    public int insertBatch(List<KafkaEvent> events) {
        int[][] results = jdbc.batchUpdate(INSERT, events, 500, (ps, message) -> {
            EventPayload e = message.event();
            ps.setString(1, message.projectId());
            ps.setString(2, e.eventId());
            ps.setString(3, e.eventName());
            ps.setObject(4, OffsetDateTime.ofInstant(e.timestamp(), ZoneOffset.UTC));
            ps.setObject(5, OffsetDateTime.ofInstant(message.receivedAt(), ZoneOffset.UTC));
            ps.setString(6, e.sessionId());
            ps.setString(7, e.anonymousId());
            ps.setString(8, e.userId());
            ps.setString(9, toJson(e.properties()));
            ps.setString(10, toJson(e.context()));
            if (e.schemaVersion() == null) ps.setNull(11, Types.INTEGER); else ps.setInt(11, e.schemaVersion());
        });
        int inserted = 0;
        for (int[] chunk : results) {
            for (int count : chunk) {
                // Some drivers report SUCCESS_NO_INFO (-2) instead of a row count.
                if (count > 0 || count == java.sql.Statement.SUCCESS_NO_INFO) inserted++;
            }
        }
        return inserted;
    }

    private String toJson(Map<String, Object> map) {
        try {
            return mapper.writeValueAsString(map == null ? Map.of() : map);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("properties are not valid JSON", e);
        }
    }
}
