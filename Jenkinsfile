pipeline {
    agent none  // Do not use a global agent

    stages {
        stage('Build and Test') {
            agent {
                docker {
                    image 'docker:20.10.7'  // Docker image with Docker CLI
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'  // Docker socket mount
                }
            }
            steps {
                script {
                    sh 'mvn clean package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true'
                    junit '**/target/surefire-reports/*.xml'  // Publish test results
                }
            }
        }

        stage('SonarCloud Analysis') {
            agent {
                docker {
                    image 'maven:3.8.4-jdk-11'  // Use Maven Docker image for this stage
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    withSonarQubeEnv('SonarCloud') {  // Use SonarQube environment configured in Jenkins
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

        stage('Snyk Dependency Scan') {
            agent {
                docker {
                    image 'node:16'  // Use Node.js Docker image for this stage
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    sh '''#!/bin/bash
                        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
                        export NVM_DIR="${NVM_DIR}"
                        [ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
                        nvm install node
                        nvm use node
                        export PATH="$NVM_DIR/versions/node/$(nvm version)/bin:$PATH"
                        npm install -g snyk
                        snyk auth ${SNYK_TOKEN}
                        snyk test --all-projects --json > snyk-report.json
                        if [ $(jq '.vulnerabilities | length' snyk-report.json) -gt 0 ]; then
                            echo "Vulnerabilities found:"
                            cat snyk-report.json
                            exit 1
                        else
                            echo "No vulnerabilities found."
                        fi
                    '''
                }
            }
        }

        stage('Package and Archive Artifact') {
            agent {
                docker {
                    image 'maven:3.8.4-jdk-11'  // Use Maven Docker image
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    sh 'mvn package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true'
                    archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false
                }
            }
        }

        stage('Build Docker Image') {
            agent {
                docker {
                    image 'docker:20.10.7'  // Docker CLI image for building Docker images
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    sh 'docker build -t $ACR_REPO:$GIT_COMMIT .'
                    withCredentials([usernamePassword(credentialsId: 'acr-credentials', passwordVariable: 'ACR_PASSWORD', usernameVariable: 'ACR_USERNAME')]) {
                        sh "az acr login --name $ACR_NAME --username $ACR_USERNAME --password $ACR_PASSWORD"
                    }
                    sh "docker push $ACR_REPO:$GIT_COMMIT"
                }
            }
        }
    }

    post {
        always {
            cleanWs()
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
