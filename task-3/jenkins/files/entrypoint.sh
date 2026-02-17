#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME="/var/jenkins_home"
mkdir -p "$JENKINS_HOME/init.groovy.d" /var/jenkins_logs

cp /opt/jenkins/init.groovy "$JENKINS_HOME/init.groovy.d/00-seed.groovy"

exec java \
  -Djenkins.install.runSetupWizard=false \
  -Djava.awt.headless=true \
  -DJENKINS_HOME="$JENKINS_HOME" \
  -jar /opt/jenkins/jenkins.war \
  --httpPort=8080
