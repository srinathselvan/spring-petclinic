pipeline {
    agent any

    environment {
        // Retrieve SonarCloud token and Snyk token from Jenkins credentials
        SONAR_TOKEN = credentials('sonarcloud-token')
        SNYK_TOKEN = credentials('snyk-token')
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
                    // Install Snyk via npm and perform vulnerability scanning
                    sh 'npm install -g snyk'
                    sh 'snyk auth ${SNYK_TOKEN}'  // Authenticate with the Snyk token
                    sh 'snyk test'  // Run the security test on dependencies
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
