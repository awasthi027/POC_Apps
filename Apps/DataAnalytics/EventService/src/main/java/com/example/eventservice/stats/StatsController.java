package com.example.eventservice.stats;

import com.example.eventservice.stats.StatsRepository.NameCount;
import com.example.eventservice.stats.StatsRepository.Point;
import com.example.eventservice.stats.StatsRepository.RecentEvent;
import com.example.eventservice.stats.StatsRepository.Summary;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** JSON for the chart page (src/main/resources/static/index.html). */
@RestController
@RequestMapping("/api")
public class StatsController {

    private static final Set<String> BUCKETS = Set.of("minute", "hour", "day");

    private final StatsRepository repository;

    public StatsController(StatsRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/projects")
    public List<String> projects() {
        return repository.projects();
    }

    @GetMapping("/stats/summary")
    public Summary summary(@RequestParam String project,
                           @RequestParam(required = false) Instant from,
                           @RequestParam(required = false) Instant to) {
        Instant end = to != null ? to : Instant.now();
        return repository.summary(project, from != null ? from : end.minus(24, ChronoUnit.HOURS), end);
    }

    /** Events per time bucket. Buckets with no events are returned with count 0 so the line has no gaps. */
    @GetMapping("/stats/timeseries")
    public List<Point> timeseries(@RequestParam String project,
                                  @RequestParam(required = false) Instant from,
                                  @RequestParam(required = false) Instant to,
                                  @RequestParam(required = false) String bucket,
                                  @RequestParam(required = false) String event) {
        Instant end = to != null ? to : Instant.now();
        Instant start = from != null ? from : end.minus(24, ChronoUnit.HOURS);
        String size = bucket != null ? bucket : chooseBucket(Duration.between(start, end));
        if (!BUCKETS.contains(size)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "bucket must be minute, hour or day");
        }
        String name = (event == null || event.isBlank()) ? null : event;

        Map<Instant, Long> counts = new HashMap<>();
        for (Point p : repository.timeseries(project, start, end, size, name)) counts.put(p.bucket(), p.count());

        ChronoUnit unit = switch (size) { case "minute" -> ChronoUnit.MINUTES; case "hour" -> ChronoUnit.HOURS; default -> ChronoUnit.DAYS; };
        List<Point> points = new ArrayList<>();
        for (Instant t = start.truncatedTo(unit); t.isBefore(end); t = t.plus(1, unit)) {
            points.add(new Point(t, counts.getOrDefault(t, 0L)));
        }
        return points;
    }

    @GetMapping("/stats/top-events")
    public List<NameCount> topEvents(@RequestParam String project,
                                     @RequestParam(required = false) Instant from,
                                     @RequestParam(required = false) Instant to,
                                     @RequestParam(defaultValue = "10") int limit) {
        Instant end = to != null ? to : Instant.now();
        return repository.topEvents(project, from != null ? from : end.minus(24, ChronoUnit.HOURS), end, Math.min(Math.max(limit, 1), 50));
    }

    @GetMapping("/events/recent")
    public List<RecentEvent> recent(@RequestParam String project, @RequestParam(defaultValue = "20") int limit) {
        return repository.recent(project, Math.min(Math.max(limit, 1), 100));
    }

    private static String chooseBucket(Duration range) {
        if (range.compareTo(Duration.ofHours(3)) <= 0) return "minute";
        if (range.compareTo(Duration.ofDays(3)) <= 0) return "hour";
        return "day";
    }
}
