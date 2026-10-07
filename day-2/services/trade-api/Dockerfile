# syntax=docker/dockerfile:1

# ---- build: compile the service and download the OpenTelemetry Java agent
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
# The first build downloads dependencies and takes a few minutes.
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests package

# ---- runtime
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/trade-api.jar /app/app.jar
COPY --from=build /src/target/agent/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
EXPOSE 8080
ENTRYPOINT ["java", "-javaagent:/otel/opentelemetry-javaagent.jar", "-jar", "/app/app.jar"]
