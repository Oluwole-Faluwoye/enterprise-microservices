ARG JAVA_VERSION=17

FROM maven:3.9-eclipse-temurin-${JAVA_VERSION} AS build

WORKDIR /workspace

COPY pom.xml .
RUN mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B clean package -DskipTests

FROM eclipse-temurin:${JAVA_VERSION}-jre-jammy AS runtime

WORKDIR /app

RUN useradd --system --uid 10001 --create-home appuser

COPY --from=build /workspace/target/*.jar /app/app.jar

ENV SERVER_PORT=8080

EXPOSE 8080

USER 10001:10001

ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/app.jar"]