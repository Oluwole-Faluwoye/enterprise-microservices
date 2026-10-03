package com.platform.auth.controller;

import org.springframework.boot.actuate.health.HealthComponent;
import org.springframework.boot.actuate.health.HealthEndpoint;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
public class PlatformHealthController {

    private final HealthEndpoint healthEndpoint;

    public PlatformHealthController(HealthEndpoint healthEndpoint) {
        this.healthEndpoint = healthEndpoint;
    }

    @GetMapping("/health/live")
    public Map<String, String> live() {
        HealthComponent health =
                healthEndpoint.healthForPath("liveness");

        return Map.of(
                "status",
                health.getStatus().getCode()
        );
    }

    @GetMapping("/health/ready")
    public Map<String, String> ready() {
        HealthComponent health =
                healthEndpoint.healthForPath("readiness");

        return Map.of(
                "status",
                health.getStatus().getCode()
        );
    }
}