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
                    sh 'mvn clean package'
                    junit '**/target/surefire-reports/*.xml'  // Publish test results
                }
            }
        }

        // Stage for running SonarCloud analysis
        stage('SonarCloud Analysis') {
            steps {
                script {
                    withSonarQubeEnv('SonarCloud') {
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

        // Stage for installing Snyk and running a dependency scan
        stage('Snyk Dependency Scan') {
            steps {
                script {
                    // Install nvm, Node.js, and Snyk
                    sh """
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
                        export NVM_DIR="\$HOME/.nvm"
                        [ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
                        nvm install 14
                        npm install -g snyk
                    """
                    // Authenticate and run Snyk test
                    sh 'snyk auth ${SNYK_TOKEN}'
                    sh 'snyk test'
                }
            }
        }

        // Stage for packaging and archiving the build artifact
        stage('Package and Archive Artifact') {
            steps {
                script {
                    sh 'mvn package'
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
    }
}
