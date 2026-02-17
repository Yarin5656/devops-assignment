import jenkins.model.*
import hudson.model.*
import hudson.tasks.Shell
import hudson.triggers.TimerTrigger
import hudson.security.*

Jenkins j = Jenkins.get()

// Keep this lab open for local demo use.
j.setSecurityRealm(SecurityRealm.NO_AUTHENTICATION)
def auth = new FullControlOnceLoggedInAuthorizationStrategy()
auth.setAllowAnonymousRead(true)
j.setAuthorizationStrategy(auth)

String jobName = "ha-monitor"
FreeStyleProject job = (FreeStyleProject) j.getItem(jobName)
if (job == null) {
    job = j.createProject(FreeStyleProject, jobName)
}
job.setDescription("Checks floating IP every 5 minutes and appends logs.")

String script = '''#!/bin/bash
set -euo pipefail
URL="http://172.28.0.100:80"
HEADERS_FILE="$(mktemp)"
BODY="$(curl -sS -D "$HEADERS_FILE" "$URL")"
BODY_CLEAN="$(echo "$BODY" | tr -d '\\r\\n')"
NODE="$(awk -F': ' 'tolower($1)=="x-active-node" {gsub("\\r","",$2); print $2}' "$HEADERS_FILE" | tail -n1)"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "$TS | body=$BODY_CLEAN | active_node=${NODE:-unknown}" >> /var/jenkins_logs/ha_monitor.log
rm -f "$HEADERS_FILE"
'''

job.getBuildersList().clear()
job.getBuildersList().add(new Shell(script))
job.getTriggers().clear()
TimerTrigger timer = new TimerTrigger('H/5 * * * *')
job.addTrigger(timer)
timer.start(job, true)
job.save()

// Ensure monitoring starts immediately without UI interaction.
job.scheduleBuild2(0)

j.save()
