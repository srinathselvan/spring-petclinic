pipeline {
    agent any  // Do not use a global agent

    environment {
        ACR_NAME = 'securecicdregistry'
        ACR_REPO = 'securecicdregistry.azurecr.io/secure-ci-cd-app'
        SONAR_TOKEN = credentials('sonarcloud-token')
        SNYK_TOKEN = credentials('snyk-token')
        NVM_DIR = "${env.HOME}/.nvm"
        AZURE_CLIENT_ID = credentials('azure-client-id')
        AZURE_CLIENT_SECRET = credentials('azure-client-secret')
        AZURE_TENANT_ID = credentials('azure-tenant-id')
        AZURE_SUBSCRIPTION_ID = 'f12d70fd-1146-4203-83b8-80ca66596958'
        KUBE_CONFIG = '/var/lib/jenkins/.kube/config'  // Path for kubeconfig file in Jenkins
    }

    tools {
        jdk 'JDK17'
        maven 'Maven'
    }

    stages {
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
                    sh 'mvn clean install -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true -DskipTests'
                    
                    def reportExists = fileExists '**/target/surefire-reports/*.xml'
                    
                    if (reportExists) {
                        junit '**/target/surefire-reports/*.xml'
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
                    withSonarQubeEnv('SonarCloud') {
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
                    sh 'mvn package -Dmaven.checkstyle.skip=true -Dcheckstyle.skip=true -DskipTests'
                    
                    def jarFiles = sh(script: 'ls target/*.jar', returnStdout: true).trim()
                    
                    if (jarFiles) {
                        archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false
                    } else {
                        echo "No JAR files found to archive."
                        currentBuild.result = 'UNSTABLE'
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

        stage('Azure Login') {
            steps {
                script {
                    sh '''
                        az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
                        az account set --subscription $AZURE_SUBSCRIPTION_ID
                    '''
                }
            }
        }

stage('Deploy to AKS') {
    agent {
        docker {
            image 'mcr.microsoft.com/azure-cli'  // Azure CLI image
            args '--privileged -v /var/run/docker.sock:/var/run/docker.sock --user root --entrypoint=""'
        }
    }
    steps {
        script {
            try {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBE_CONFIG')]) {
                    sh '''
                        # Print environment variables for debugging
                        echo "Home Directory: $HOME"
                        echo "Current User: $(whoami)"
                        
                        # Install kubectl
                        curl -LO https://dl.k8s.io/release/v1.23.13/bin/linux/amd64/kubectl
                        chmod +x kubectl
                        mv kubectl /usr/local/bin/

                        # Set up kubeconfig
                        mkdir -p ~/.kube
                        cp $KUBE_CONFIG ~/.kube/config

                        # Authenticate Azure CLI and set kubeconfig context
                        az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
                        az account set --subscription $AZURE_SUBSCRIPTION_ID
                        az aks get-credentials --resource-group myVm_group --name securecicd-cluster --overwrite-existing

                        # Apply Kubernetes manifests
                        kubectl apply -f ~/spring-petclinic/k8s/deployment.yaml
                        kubectl apply -f ~/spring-petclinic/k8s/service.yaml
                    '''
                }
            } catch (Exception e) {
                // Log the error and fail the stage
                echo "An error occurred during deployment: ${e.getMessage()}"
                currentBuild.result = 'FAILURE'
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
