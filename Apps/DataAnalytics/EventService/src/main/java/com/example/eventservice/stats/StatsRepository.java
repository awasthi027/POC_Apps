package com.example.eventservice.stats;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

/** Read-only queries for the chart page. */
@Repository
public class StatsRepository {

    public record Point(Instant bucket, long count) {}
    public record NameCount(String name, long count) {}
    public record Summary(long totalEvents, long uniqueUsers, long sessions, long eventTypes) {}
    public record RecentEvent(String name, Instant time, String userId, String anonymousId, String sessionId) {}

    private final JdbcTemplate jdbc;

    public StatsRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<String> projects() {
        return jdbc.queryForList("SELECT DISTINCT project_id FROM events ORDER BY project_id", String.class);
    }

    /** @param bucket "minute", "hour" or "day" (already checked by the caller; it is put into the query text). */
    public List<Point> timeseries(String project, Instant from, Instant to, String bucket, String eventName) {
        List<Object> args = new ArrayList<>();
        String sql = "SELECT date_trunc('" + bucket + "', event_time AT TIME ZONE 'UTC') AS bucket, count(*) AS n "
                + "FROM events WHERE project_id = ? AND event_time >= ? AND event_time < ?";
        args.add(project); args.add(utc(from)); args.add(utc(to));
        if (eventName != null) { sql += " AND event_name = ?"; args.add(eventName); }
        sql += " GROUP BY 1 ORDER BY 1";
        return jdbc.query(sql, (rs, i) -> new Point(
                rs.getObject(1, java.time.LocalDateTime.class).toInstant(ZoneOffset.UTC), rs.getLong(2)), args.toArray());
    }

    public List<NameCount> topEvents(String project, Instant from, Instant to, int limit) {
        return jdbc.query("""
                SELECT event_name, count(*) FROM events
                WHERE project_id = ? AND event_time >= ? AND event_time < ?
                GROUP BY event_name ORDER BY count(*) DESC, event_name LIMIT ?
                """, (rs, i) -> new NameCount(rs.getString(1), rs.getLong(2)), project, utc(from), utc(to), limit);
    }

    public Summary summary(String project, Instant from, Instant to) {
        return jdbc.queryForObject("""
                SELECT count(*),
                       count(DISTINCT COALESCE(user_id, anonymous_id)),
                       count(DISTINCT session_id),
                       count(DISTINCT event_name)
                FROM events WHERE project_id = ? AND event_time >= ? AND event_time < ?
                """, (rs, i) -> new Summary(rs.getLong(1), rs.getLong(2), rs.getLong(3), rs.getLong(4)),
                project, utc(from), utc(to));
    }

    public List<RecentEvent> recent(String project, int limit) {
        return jdbc.query("""
                SELECT event_name, event_time, user_id, anonymous_id, session_id FROM events
                WHERE project_id = ? ORDER BY event_time DESC, id DESC LIMIT ?
                """, (rs, i) -> new RecentEvent(rs.getString(1), rs.getObject(2, OffsetDateTime.class).toInstant(),
                rs.getString(3), rs.getString(4), rs.getString(5)), project, limit);
    }

    private static OffsetDateTime utc(Instant instant) {
        return OffsetDateTime.ofInstant(instant, ZoneOffset.UTC);
    }
}
