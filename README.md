# BoardGame Project CI/CD Pipeline

This project demonstrates a CI/CD pipeline for a Java Maven application called BoardGame. The pipeline is implemented using Jenkins and incorporates several tools and stages to ensure code quality, security, and automated deployment.

![Project Map](./Project_Flow.gif)

## Pipeline Overview

The Jenkins pipeline performs the following steps:

1. **Compile Code**
   - Compiles the Java code using Maven.
   
2. **Test Code**
   - Runs the unit tests using Maven.
   
3. **Filesystem Scan**
   - Scans the filesystem using Trivy and generates an HTML report.
   
4. **SonarQube Analysis**
   - Runs static code analysis using SonarQube.
   
5. **Quality Gate**
   - Waits for the SonarQube quality gate result.
   
6. **Build Code**
   - Packages the application using Maven.
   
7. **Push to Nexus**
   - Deploys the Maven artifact to Nexus.
   
8. **Build & Tag Docker Image**
   - Builds and tags the Docker image.
   
9. **Docker Image Scan**
   - Scans the Docker image using Trivy and generates an HTML report.
   
10. **Push Docker Image to Nexus**
    - Pushes the Docker image to Nexus.
    
11. **Change Image Version in Kubernetes**
    - Updates the Kubernetes deployment YAML file with the new Docker image tag.
    
12. **Deploy to EKS Cluster**
    - Deploys the updated application to the EKS cluster.

## Environment Variables

- `SCANNER_HOME`: Path to the SonarQube scanner.
- `NEXUS_SERVER`: Nexus server address.
- `DOCKER_REGISTRY`: Docker registry URL.
- `IMAGE_TAG`: Docker image tag, typically the Jenkins build number.

## Tools and Technologies

- **JDK 17**
- **Maven 3**
- **SonarQube**: For static code analysis.
- **Trivy**: For filesystem and Docker image scanning.
- **Nexus**: For artifact and Docker image storage.
- **Docker**: For containerizing the application.
- **Kubernetes**: For deploying the application.

## Jenkins Pipeline Script

Here is the complete Jenkins pipeline script used in this project:

```groovy
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
        stage("change image version in k8s") {
            steps {
                script {
                    sh "sed -i \"s|image:.*|image: ${NEXUS_SERVER}/boardgame:${IMAGE_TAG}|g\" deployment-service.yaml"
                }
            }
        }
         stage('Deploy to eks cluster') {
            steps {
                echo 'Deploying to eks cluster ... '
                withCredentials([file(credentialsId:'kube-config', variable:'KUBECONFIG')]){
                    script{
                        sh 'kubectl apply -f deployment-service.yaml'
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
```


## Usage

### Set up Jenkins
1. Install the necessary tools and plugins in Jenkins.
2. Configure the environment variables and credentials.

### Run the Pipeline
Trigger the pipeline to start the build, test, scan, and deployment process.

### Check Reports
Review the Trivy reports and SonarQube analysis for any issues.

### Monitor Deployment
Ensure the application is successfully deployed to the EKS cluster.
