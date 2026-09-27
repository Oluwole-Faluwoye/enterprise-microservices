package com.platform.auth.config;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class LocalEnvironmentCredentialProviderTest {

    @Test
    void shouldReturnCredentialsWhenEnvironmentVariablesArePresent() {

        EnvironmentProvider environmentProvider = name ->
                Map.of(
                        "DB_USERNAME", "authuser",
                        "DB_PASSWORD", "test-password"
                ).get(name);

        LocalEnvironmentCredentialProvider provider =
                new LocalEnvironmentCredentialProvider(environmentProvider);

        DatabaseCredentials credentials = provider.getCredentials();

        assertEquals("authuser", credentials.username());
        assertEquals("test-password", credentials.password());
    }

    @Test
    void shouldThrowWhenUsernameIsMissing() {

        EnvironmentProvider environmentProvider = name ->
                Map.of(
                        "DB_PASSWORD", "test-password"
                ).get(name);

        LocalEnvironmentCredentialProvider provider =
                new LocalEnvironmentCredentialProvider(environmentProvider);

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                provider::getCredentials
        );

        assertEquals(
                "Required environment variable is missing: DB_USERNAME",
                exception.getMessage()
        );
    }

    @Test
    void shouldThrowWhenPasswordIsMissing() {

        EnvironmentProvider environmentProvider = name ->
                Map.of(
                        "DB_USERNAME", "authuser"
                ).get(name);

        LocalEnvironmentCredentialProvider provider =
                new LocalEnvironmentCredentialProvider(environmentProvider);

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                provider::getCredentials
        );

        assertEquals(
                "Required environment variable is missing: DB_PASSWORD",
                exception.getMessage()
        );
    }

    @Test
    void shouldThrowWhenUsernameIsBlank() {

        EnvironmentProvider environmentProvider = name ->
                Map.of(
                        "DB_USERNAME", "   ",
                        "DB_PASSWORD", "test-password"
                ).get(name);

        LocalEnvironmentCredentialProvider provider =
                new LocalEnvironmentCredentialProvider(environmentProvider);

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                provider::getCredentials
        );

        assertEquals(
                "Required environment variable is missing: DB_USERNAME",
                exception.getMessage()
        );
    }

    @Test
    void shouldThrowWhenPasswordIsBlank() {

        EnvironmentProvider environmentProvider = name ->
                Map.of(
                        "DB_USERNAME", "authuser",
                        "DB_PASSWORD", "   "
                ).get(name);

        LocalEnvironmentCredentialProvider provider =
                new LocalEnvironmentCredentialProvider(environmentProvider);

        IllegalStateException exception = assertThrows(
                IllegalStateException.class,
                provider::getCredentials
        );

        assertEquals(
                "Required environment variable is missing: DB_PASSWORD",
                exception.getMessage()
        );
    }
}