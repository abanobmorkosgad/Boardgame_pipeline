pipeline {
    agent any 
    tools {
        jdk "jdk17"
        maven "maven3"
    }
    environment {
        SCANNER_HOME= tool "sonar"
        DOCKER_REGISTRY="http://54.152.129.4:8081/repository/docker/"
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
                    docker.build("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}")
                }
            }
        }
        stage('Docker Image Scan') {
            steps {
                sh "trivy image --format table -o trivy-image-report.html ${DOCKER_REGISTRY}/boardgame:${IMAGE_TAG}"
            }
        }
        stage("push Docker Image to nexus"){
            steps{
               script {
                    withDockerRegistry([url: "${DOCKER_REGISTRY}", credentialsId: "nexus"]) {
                        docker.image("${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}").push()
                    }
               }
            }
        }
    }
}