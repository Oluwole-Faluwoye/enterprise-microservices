package com.platform.auth.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.secretsmanager.SecretsManagerClient;
import software.amazon.awssdk.services.secretsmanager.model.GetSecretValueRequest;

@Component
public class AwsSecretsManagerCredentialProvider
        implements DatabaseCredentialProvider {

    private final ObjectMapper objectMapper = new ObjectMapper();
    private final SecretsManagerClient secretsManagerClient;

    public AwsSecretsManagerCredentialProvider() {
        this.secretsManagerClient = SecretsManagerClient.builder()
                .region(Region.of(requiredEnv("AWS_REGION")))
                .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    @Override
    public DatabaseCredentials getCredentials() {

        String secretReference = requiredEnv("DB_CREDENTIAL_REFERENCE");

        String secretString = secretsManagerClient.getSecretValue(
                GetSecretValueRequest.builder()
                        .secretId(secretReference)
                        .build()
        ).secretString();

        try {
            JsonNode credentials = objectMapper.readTree(secretString);

            String username = requiredJson(credentials, "username");
            String password = requiredJson(credentials, "password");

            return new DatabaseCredentials(username, password);

        } catch (Exception e) {
            throw new IllegalStateException(
                    "Unable to parse database credentials",
                    e
            );
        }
    }

    private String requiredEnv(String name) {
        String value = System.getenv(name);

        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "Required environment variable is missing: " + name
            );
        }

        return value;
    }

    private String requiredJson(JsonNode node, String field) {
        JsonNode value = node.get(field);

        if (value == null || value.asText().isBlank()) {
            throw new IllegalStateException(
                    "Required field missing from database credentials: " + field
            );
        }

        return value.asText();
    }
}