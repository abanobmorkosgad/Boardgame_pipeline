pipeline {
    agent any 
    tools {
        jdk "jdk17"
        maven "maven3"
    }
    environment {
        SCANNER_HOME= tool "sonar"
        NEXUS_SERVER="54.152.129.4:8082"
        DOCKER_REGISTRY="54.152.129.4:8082/repository/docker"
        IMAGE_TAG="${BUILD_NUMBER}"
    }
    stages{

        stage("compile code"){
            steps{
                sh "mvn compile"
            }
        }

        stage("test code"){
            steps{
                sh "mvn test"
            }
        }

        stage("check filesystem"){
            steps{
                sh "trivy fs --format table -o trivy-fs-report.html ."
            }
        }

        stage("sonarqube analysis"){
            steps{
                withSonarQubeEnv("sonar") {
                    sh """
                    ${SCANNER_HOME}/bin/sonar-scanner \
                    -Dsonar.projectName=BoardGame \
                    -Dsonar.projectKey=BoardGame \
                    -Dsonar.java.binaries=.
                    """
                }
            }
        }

        stage("quality gate"){
            steps{
                waitForQualityGate abortPipeline: false, credentialsId: 'sonarqube'
            }
        }

        stage("build code"){
            steps{
                sh "mvn package"
            }
        }

        stage("push to nexus"){
            steps{
                withMaven(globalMavenSettingsConfig: 'global-settings', jdk: 'jdk17', maven: 'maven3', mavenSettingsConfig: '', traceability: true) {
                    sh "mvn deploy"
                }
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                script{
                    docker.build("${NEXUS_SERVER}/boardgame:${IMAGE_TAG}")
                }
            }
        }

        stage('Docker Image Scan') {
            steps {
                sh "trivy image --format table -o trivy-image-report.html ${NEXUS_SERVER}/boardgame:${IMAGE_TAG}"
            }
        }

        stage("push Docker Image to nexus"){
            steps{
               script {
                    withDockerRegistry([url: "http://${NEXUS_SERVER}", credentialsId: "nexus"]) {
                        docker.image("${NEXUS_SERVER}/boardgame:${IMAGE_TAG}").push()
                    }
               }
            }
        }

        stage("change image version in k8s manifest") {
            steps {
                script {
                    sh "sed -i \"s|image:.*|image: ${NEXUS_SERVER}/boardgame:${IMAGE_TAG}|g\" k8s/deployment-service.yaml"
                }
            }
        }

         stage('Deploy to eks cluster') {
            steps {
                echo 'Deploying to eks cluster ... '
                withCredentials([file(credentialsId:'kube-config', variable:'KUBECONFIG')]){
                    script{
                        sh 'kubectl apply -f k8s/deployment-service.yaml'
                    }
                }
            }
        }

    }

    post {
     always {
        emailext attachLog: true,
            subject: "'${currentBuild.result}'",
            body: "Project: ${env.JOB_NAME}<br/>" +
                  "Build Number: ${env.BUILD_NUMBER}<br/>" +
                  "URL: ${env.BUILD_URL}<br/>",
            to: 'abanobmorkos13@gmail.com',                                
            attachmentsPattern: 'trivy-image-report.html'
        }
    }
    
}