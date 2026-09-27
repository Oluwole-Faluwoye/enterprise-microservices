package com.platform.auth.config;

@FunctionalInterface
public interface EnvironmentProvider {

    String get(String name);
}