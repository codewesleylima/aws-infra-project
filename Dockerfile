# Multi-stage Dockerfile for Spring Boot book library application
# Builds the Java application in a Maven stage and produces a minimal runtime image.

# ============================================
# Stage 1: Build
# ============================================
FROM maven:3.9.4-eclipse-temurin-17 AS build

WORKDIR /workspace
COPY library-app/pom.xml ./library-app/
RUN mvn -f library-app/pom.xml -B -Dmaven.repo.local=/root/.m2/repository dependency:go-offline

COPY library-app ./library-app
RUN mvn -f library-app/pom.xml -B -Dmaven.repo.local=/root/.m2/repository package -DskipTests

# ============================================
# Stage 2: Runtime
# ============================================
FROM eclipse-temurin:17-jdk-jammy

WORKDIR /app
COPY --from=build /workspace/library-app/target/library-app-0.0.1-SNAPSHOT.jar /app/library-app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/library-app.jar"]
