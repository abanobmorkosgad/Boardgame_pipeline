FROM adoptopenjdk/openjdk11
  
EXPOSE 8080

COPY target/*.jar /usr/src/app/app.jar

WORKDIR /usr/src/app

CMD ["java", "-jar", "app.jar"]
