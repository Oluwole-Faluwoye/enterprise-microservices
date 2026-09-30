package com.enterprise.platform.runtime;

import io.micrometer.prometheusmetrics.PrometheusMeterRegistry;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PlatformMetricsController {

    private final PrometheusMeterRegistry registry;

    public PlatformMetricsController(PrometheusMeterRegistry registry) {
        this.registry = registry;
    }

    @GetMapping(value = "/metrics", produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> metrics() {
        return ResponseEntity.ok(registry.scrape());
    }
}
