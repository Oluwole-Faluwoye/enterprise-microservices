package com.enterprise.platform.runtime;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT
)
class PlatformContractTest {

    @LocalServerPort
    int port;

    private final HttpClient client = HttpClient.newHttpClient();

    @Test
    void platformHealthContractIsSatisfied() throws Exception {

        assertHealthEndpointReturns200("/health/live");
        assertHealthEndpointReturns200("/health/ready");
        assertEndpointReturns200("/metrics");
    }

    private void assertHealthEndpointReturns200(String path)
            throws Exception {

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(
                        "http://localhost:" + port + path
                ))
                .GET()
                .build();

        HttpResponse<String> response =
                client.send(
                        request,
                        HttpResponse.BodyHandlers.ofString()
                );

        assertEquals(
                200,
                response.statusCode(),
                path + " should return HTTP 200"
        );

        assertEquals(
                true,
                response.body().contains("\"status\":\"UP\""),
                path + " should report UP"
        );
    }

    private void assertEndpointReturns200(String path)
            throws Exception {

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(
                        "http://localhost:" + port + path
                ))
                .GET()
                .build();

        HttpResponse<String> response =
                client.send(
                        request,
                        HttpResponse.BodyHandlers.ofString()
                );

        assertEquals(
                200,
                response.statusCode(),
                path + " should return HTTP 200"
        );
    }
}