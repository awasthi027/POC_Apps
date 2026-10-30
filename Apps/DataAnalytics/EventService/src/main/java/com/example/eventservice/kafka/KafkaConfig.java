package com.example.eventservice.kafka;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;
import org.springframework.kafka.listener.CommonErrorHandler;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.util.backoff.FixedBackOff;

@Configuration
public class KafkaConfig {

    @Bean
    NewTopic eventsTopic(@Value("${analytics.topic}") String topic,
                         @Value("${analytics.partitions}") int partitions,
                         @Value("${analytics.replicas}") int replicas) {
        return TopicBuilder.name(topic).partitions(partitions).replicas(replicas).build();
    }

    /** Messages we could not store (bad JSON, rows Postgres refuses) go here, so they never block the main topic. */
    @Bean
    NewTopic deadLetterTopic(@Value("${analytics.topic}") String topic,
                             @Value("${analytics.replicas}") int replicas) {
        return TopicBuilder.name(topic + ".dlt").partitions(1).replicas(replicas).build();
    }

    /**
     * When the consumer throws (for example Postgres is down), wait 2 seconds and run the same batch again,
     * without limit. The offsets are not committed, so nothing is lost: Kafka keeps the events until we succeed.
     */
    @Bean
    CommonErrorHandler errorHandler() {
        return new DefaultErrorHandler(new FixedBackOff(2000L, FixedBackOff.UNLIMITED_ATTEMPTS));
    }
}
