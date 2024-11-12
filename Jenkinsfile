pipeline {
    agent any  // Do not use a global agent

    environment {
        ACR_NAME = 'securecicdregistry'
        ACR_REPO = 'securecicdregistry.azurecr.io/secure-ci-cd-app'
        SONAR_TOKEN = credentials('sonarcloud-token')
        SNYK_TOKEN = credentials('snyk-token')
        NVM_DIR = "${env.HOME}/.nvm"
    }

    tools {
        jdk 'JDK17'
        maven 'Maven'
    }

    stages {
        // Add the Verify Docker stage at the beginning
        stage('Verify Docker') {
            agent any
            steps {
                script {
                    sh 'docker --version'
                }
            }
        }

        stage('Build and Test') {
            agent {
                docker {
                    image 'srinathselvan/my-maven-jdk-17'
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    // Compile and run tests only if tests are not skipped
                    sh 'mvn clean install -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true -DskipTests'
                    
                    // Check if test reports exist before running the junit step
                    def reportExists = fileExists '**/target/surefire-reports/*.xml'
                    
                    if (reportExists) {
                        junit '**/target/surefire-reports/*.xml'  // Publish test results if report exists
                    } else {
                        echo 'No test reports found. Skipping junit step.'
                    }
                }
            }
        }

        stage('SonarCloud Analysis') {
            agent {
                docker {
                    image 'srinathselvan/my-maven-jdk-17'
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    withSonarQubeEnv('SonarCloud') {  // SonarQube environment configured in Jenkins
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.organization=srinathselvan \
                                -Dsonar.projectKey=srinathselvan_spring-petclinic \
                                -Dsonar.login=$SONAR_TOKEN \
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
                    image 'node:16'
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
                        snyk auth $SNYK_TOKEN
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
                    image 'srinathselvan/my-maven-jdk-17'
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
                }
            }
            steps {
                script {
                    // Add -DskipTests to ensure tests are skipped during packaging
                    sh 'mvn package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true -DskipTests'
                    
                    // Check if the .jar files are created in the target directory
                    def jarFiles = sh(script: 'ls target/*.jar', returnStdout: true).trim()
                    
                    if (jarFiles) {
                        archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false
                    } else {
                        echo "No JAR files found to archive."
                        currentBuild.result = 'UNSTABLE'  // Mark build as unstable if no JAR files are found
                    }
                }
            }
        }

        stage('Build Docker Image') {
            agent {
                docker {
                    image 'docker:20.10.7'
                    args '--privileged -v /var/run/docker.sock:/var/run/docker.sock --user root'
                }
            }
            steps {
                script {
                    sh 'pwd'
                    sh 'ls -l'
                    sh 'docker build -t $ACR_REPO:$GIT_COMMIT ./'
                    withCredentials([usernamePassword(credentialsId: 'acr-credentials', passwordVariable: 'ACR_PASSWORD', usernameVariable: 'ACR_USERNAME')]) {
                        sh "echo $ACR_PASSWORD | docker login $ACR_REPO --username $ACR_USERNAME --password-stdin"
                    }
                    sh "docker push $ACR_REPO:$GIT_COMMIT"
                }
            }
        }

        // New 'Deploy to AKS' stage
		stage('Deploy to AKS') {
			steps {
				script {
					withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBE_CONFIG')]) {
						sh '''
							# Install kubectl if not already available
							if ! command -v kubectl &> /dev/null
							then
								echo "kubectl could not be found, installing..."
								curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.23.0/bin/linux/amd64/kubectl
								chmod +x ./kubectl
								
								# Move kubectl to a user-specific directory
								mkdir -p $HOME/.local/bin
								mv ./kubectl $HOME/.local/bin/kubectl
							else
								echo "kubectl is already installed"
							fi
							
							# Add the user-specific bin directory to the PATH
							export PATH=$HOME/.local/bin:$PATH
							
							# Now deploy to AKS
							kubectl --kubeconfig=$KUBE_CONFIG apply -f k8s/deployment.yaml
							kubectl --kubeconfig=$KUBE_CONFIG apply -f k8s/service.yaml
						'''
					}
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
                def issuesFound = snykJson.vulnerabilities.size() > 0

                if (issuesFound) {
                    currentBuild.result = 'UNSTABLE'
                    echo "Vulnerabilities found in the project!"
                    archiveArtifacts artifacts: 'snyk-report.json', allowEmptyArchive: true
                }
            }
        }
    }
}
