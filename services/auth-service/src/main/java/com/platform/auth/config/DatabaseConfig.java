package com.platform.auth.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import javax.sql.DataSource;

@Configuration
@ConditionalOnProperty(
        name = "app.database.enabled",
        havingValue = "true",
        matchIfMissing = true
)
public class DatabaseConfig {

    @Bean
    public DataSource dataSource(
            DatabaseCredentialProvider credentialProvider
    ) {

        String host = requiredEnv("DB_HOST");
        String port = envOrDefault("DB_PORT", "5432");
        String databaseName = requiredEnv("DB_NAME");

        DatabaseCredentials credentials =
                credentialProvider.getCredentials();

        DriverManagerDataSource dataSource =
                new DriverManagerDataSource();

        dataSource.setDriverClassName("org.postgresql.Driver");

        dataSource.setUrl(
                String.format(
                        "jdbc:postgresql://%s:%s/%s",
                        host,
                        port,
                        databaseName
                )
        );

        dataSource.setUsername(credentials.username());
        dataSource.setPassword(credentials.password());

        return dataSource;
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

    private String envOrDefault(String name, String defaultValue) {
        String value = System.getenv(name);

        return value == null || value.isBlank()
                ? defaultValue
                : value;
    }
}
