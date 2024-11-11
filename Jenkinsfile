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
                    sh """
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
                        export NVM_DIR="${NVM_DIR}"
                        [ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
                        nvm install node
                        nvm use node
                        export PATH="\$NVM_DIR/versions/node/$(nvm version)/bin:\$PATH"
                        node -v  # Check Node.js version
                        npm -v   # Check npm version
                        npm install -g snyk
                        snyk auth ${SNYK_TOKEN}  # Authenticate with Snyk token
                        snyk test  # Run Snyk security scan
                    """
                }
            }
        }

        // Stage for packaging and archiving the build artifact
        stage('Package and Archive Artifact') {
            steps {
                script {
                    // Run Maven package to generate the .jar file
                    sh 'mvn package'
                    archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false  // Archive the .jar file
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
    }
}
