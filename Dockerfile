# Use your custom image for the build process
FROM srinathselvan/my-maven-jdk-17 AS build

# Set the working directory in the container
WORKDIR /app

# Copy the pom.xml and source code into the container
COPY pom.xml .
COPY src ./src

# Build the application
RUN mvn clean install -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true

# Package the application
RUN mvn package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true -DskipTests

# Final image with the runtime environment
FROM openjdk:17-jdk-slim

# Set the working directory in the container
WORKDIR /app

# Copy the packaged JAR file from the build stage
COPY --from=build /app/target/*.jar app.jar

# Expose the port on which the app will run
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
