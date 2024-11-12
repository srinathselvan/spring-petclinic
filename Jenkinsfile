pipeline {
    agent {
        docker {
            image 'docker:20.10.7' // Use a Docker image with Docker CLI installed
            args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    environment {
        // Retrieve SonarCloud token and Snyk token from Jenkins credentials
        SONAR_TOKEN = credentials('sonarcloud-token')
        SNYK_TOKEN = credentials('snyk-token')
        NVM_DIR = "${env.HOME}/.nvm"
		
		// New Docker and ACR environment variables
        ACR_NAME = 'securecicdregistry'
        ACR_REPO = 'securecicdregistry.azurecr.io/secure-ci-cd-app'
    }

    tools {
        // Define tools required for the pipeline
        jdk 'JDK11'
        maven 'Maven'
    }

    stages {
        // Stage for building and testing the project
        stage('Build and Test') {
            steps {
                script {
                    // Run Maven build and tests with Checkstyle disabled explicitly
                    sh 'mvn clean package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true'
                    junit '**/target/surefire-reports/*.xml'  // Publish test results
                }
            }
        }

        // Stage for running SonarCloud analysis
        stage('SonarCloud Analysis') {
            steps {
                script {
                    withSonarQubeEnv('SonarCloud') {  // Use the SonarQube environment configured in Jenkins
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.organization=srinathselvan \
                                -Dsonar.projectKey=srinathselvan_spring-petclinic \
                                -Dsonar.login=${SONAR_TOKEN} \
                                -Dmaven.checkstyle.skip=true \
                                -Dcheckstyle.skip=true
                        """
                    }
                }
            }
        }

        // Stage for running Snyk security vulnerability scan
        stage('Snyk Dependency Scan') {
            steps {
                script {
                    // Install Node.js, nvm, and Snyk in the same shell environment
                    sh '''#!/bin/bash
                        # Install NVM
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

                        # Set NVM_DIR and source nvm.sh
                        export NVM_DIR="${NVM_DIR}"
                        [ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"

                        # Install and use Node.js
                        nvm install node
                        nvm use node
                        export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"

                        # Check Node.js and npm versions
                        node -v  # Ensure Node.js is installed
                        npm -v   # Ensure npm is installed

                        # Install Snyk
                        npm install -g snyk

                        # Authenticate with Snyk using the provided token
                        snyk auth ${SNYK_TOKEN}

                        # Run the security scan on all projects and output results in JSON format
                        snyk test --all-projects --json > snyk-report.json

                        # Parse the JSON output to check if there are any issues
                        if [ $(jq '.vulnerabilities | length' snyk-report.json) -gt 0 ]; then
                            echo "Vulnerabilities found:"
                            cat snyk-report.json  # Output vulnerabilities for debugging
                            exit 1  # Fail the build if vulnerabilities are found
                        else
                            echo "No vulnerabilities found."
                        fi
                    '''
                }
            }
        }

        // Stage for packaging and archiving the build artifact
        stage('Package and Archive Artifact') {
            steps {
                script {
                    // Run Maven package to generate the .jar file with Checkstyle disabled explicitly
                    sh 'mvn package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true'
                    archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false  // Archive the .jar file
                }
            }
        }
		
		stage('Build Docker Image') {
            steps {
                script {
                    // Build Docker image with the Git commit hash as the tag
                    sh 'docker build -t $ACR_REPO:$GIT_COMMIT .'

                    // Login to Azure Container Registry (ACR)
                    withCredentials([usernamePassword(credentialsId: 'acr-credentials', passwordVariable: 'ACR_PASSWORD', usernameVariable: 'ACR_USERNAME')]) {
                        sh "az acr login --name $ACR_NAME --username $ACR_USERNAME --password $ACR_PASSWORD"
                    }

                    // Push Docker image to ACR
                    sh "docker push $ACR_REPO:$GIT_COMMIT"
                }
            }
        }
    }

    post {
        always {
            cleanWs()  // Clean workspace after each build
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed. Check logs for errors.'
        }
        unstable {
            script {
                def snykReport = readFile('snyk-report.json')
                def snykJson = readJSON text: snykReport
                def issuesFound = snykJson.issues.size() > 0

                if (issuesFound) {
                    currentBuild.result = 'UNSTABLE'
                    echo "Vulnerabilities found in the project!"
                    archiveArtifacts artifacts: 'snyk-report.json', allowEmptyArchive: true
                }
            }
        }
    }
}