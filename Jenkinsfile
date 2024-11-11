pipeline {
    agent any

    environment {
        // Retrieve SonarCloud token and Snyk token from Jenkins credentials
        SONAR_TOKEN = credentials('sonarcloud-token')
        SNYK_TOKEN = credentials('snyk-token')
        NVM_DIR = "${env.HOME}/.nvm"
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
                    // Run Maven build and tests
                    sh 'mvn clean package'
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
                                -Dsonar.login=${SONAR_TOKEN}
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
                    // Run Maven package to generate the .jar file
                    sh 'mvn package'

                    // Temporarily disable Checkstyle for packaging stage
                    sh '''
                        mvn checkstyle:checkstyle -Dmaven.checkstyle.skip=true
                    '''

                    // Archive the .jar file
                    archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false
                }
            }
        }
    }

    // Post build actions
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
                // Read the Snyk report and handle the findings
                def snykReport = readFile('snyk-report.json')
                def snykJson = readJSON text: snykReport
                def issuesFound = snykJson.issues.size() > 0

                if (issuesFound) {
                    // Optionally, you can fail the build or just mark it unstable
                    currentBuild.result = 'UNSTABLE'  // Mark build as unstable if vulnerabilities are found
                    echo "Vulnerabilities found in the project!"
                    archiveArtifacts artifacts: 'snyk-report.json', allowEmptyArchive: true  // Archive the snyk report
                    // You can also add email notifications or alert mechanisms here
                }
            }
        }
    }
}
