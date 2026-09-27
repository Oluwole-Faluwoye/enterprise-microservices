package com.platform.auth.config;

import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile("local")
public class LocalEnvironmentCredentialProvider
        implements DatabaseCredentialProvider {

    private final EnvironmentProvider environmentProvider;

    public LocalEnvironmentCredentialProvider() {
        this(System::getenv);
    }

    LocalEnvironmentCredentialProvider(EnvironmentProvider environmentProvider) {
        this.environmentProvider = environmentProvider;
    }

    @Override
    public DatabaseCredentials getCredentials() {
        String username = requiredEnv("DB_USERNAME");
        String password = requiredEnv("DB_PASSWORD");

        return new DatabaseCredentials(username, password);
    }

    private String requiredEnv(String name) {
        String value = environmentProvider.get(name);

        if (value == null || value.isBlank()) {
            throw new IllegalStateException(
                    "Required environment variable is missing: " + name
            );
        }

        return value;
    }
}