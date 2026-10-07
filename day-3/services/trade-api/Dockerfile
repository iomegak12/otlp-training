# syntax=docker/dockerfile:1
# trade-api image WITHOUT any OpenTelemetry agent: on Kubernetes the OpenTelemetry Operator
# injects the Java agent when the pod is created (annotation instrumentation.opentelemetry.io/inject-java).

# ---- build
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN --mount=type=cache,target=/root/.m2 mvn -B -DskipTests package

# ---- runtime
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/trade-api.jar /app/app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
