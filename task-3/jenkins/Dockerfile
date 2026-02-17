FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      fontconfig \
      openjdk-11-jre-headless && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/jenkins /var/jenkins_home /var/jenkins_logs

# Jenkins LTS line that supports Java 11.
RUN curl -fsSL -o /opt/jenkins/jenkins.war \
      https://get.jenkins.io/war-stable/2.414.3/jenkins.war

COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY files/init.groovy /opt/jenkins/init.groovy

RUN chmod +x /usr/local/bin/entrypoint.sh && \
    sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
