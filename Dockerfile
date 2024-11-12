# Use a base image with OpenJDK 17 and Maven pre-installed
FROM maven:3.8.5-openjdk-17-slim AS build

# Check if root user exists; if not, create it
RUN if ! id -u root >/dev/null 2>&1; then useradd -m root; fi

# Switch to root user for installation
USER root

# Install necessary tools (e.g., Docker CLI) in the container
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    sudo \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and NVM for Snyk (since you are using Node.js in the 'Snyk Dependency Scan' stage)
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR /root/.nvm
RUN ["/bin/bash", "-c", ". $NVM_DIR/nvm.sh && nvm install node"]

# Set up the Maven environment
ENV MAVEN_HOME /usr/share/maven
ENV PATH $MAVEN_HOME/bin:$PATH

# Switch to a non-root user after installation (e.g., 'jenkins')
USER jenkins

# Set the default command
CMD ["mvn", "-v"]
