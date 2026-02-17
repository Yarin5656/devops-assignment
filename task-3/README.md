# Task-3 — Pacemaker/Corosync Floating IP + Apache + Jenkins Monitor (Docker)

## Goal
Build a 4-node Docker lab:
- 3 nodes form an HA cluster (Pacemaker + Corosync) with a Floating VIP.
- Apache2 listens on the Floating IP and serves a homepage text:
  **"Junior DevOps Engineer - Home Task"**
- 4th node (not in cluster) runs Jenkins with a job that:
  - sends curl to the floating IP every 5 minutes
  - appends results to a log file with timestamp + container name that answered
  - log must be accessible from the host (volume mount)

Containers:
- webz-001, webz-002, webz-003  (cluster nodes)
- webz-004 (Jenkins node)

OS image: Ubuntu 18.04 (as required)

---

## What was implemented
- **4 Ubuntu 18.04 containers** with fixed/static IPs on a dedicated Docker bridge network.
- **Pacemaker + Corosync cluster** on webz-001..003 with a **Floating VIP**:
  - VIP: `172.28.0.100`
  - Cluster defines resource(s) for VIP and Apache.
  - Failover order is controlled by cluster constraints (preferred active node order).
- **Apache2 configured to bind/listen on the Floating VIP** and serve:
  `Junior DevOps Engineer - Home Task`
- **Jenkins on webz-004**:
  - pre-seeded job named `ha-monitor`
  - runs **every 5 minutes** (cron: `H/5 * * * *`)
  - performs `curl` to `http://172.28.0.100`
  - appends to a host-mounted log: `task-3/logs/ha_monitor.log`
  - each log line includes timestamp + body + detected active node name.

---

## Repository layout
- `docker-compose.yml` — defines all 4 containers, network, fixed IPs, volumes.
- `cluster/` — cluster scripts/config:
  - `bootstrap_cluster.sh` — installs + configures corosync/pacemaker + resources/constraints
  - `apache-site.conf` — Apache vhost/homepage configuration
- `jenkins/` — Jenkins setup:
  - `Dockerfile` — Jenkins image setup
  - `files/init.groovy` — auto-create job on startup
  - `files/entrypoint.sh` — init wiring
- `logs/` — host-visible logs (mounted from Jenkins container)
  - `ha_monitor.log`
- `run_all.ps1` — **single entry script** to bring everything up + initialize
- `README.md` — this file

---

## Prerequisites
- Docker Desktop installed
- Docker Desktop **Linux containers mode** (required)
- PowerShell

---

## One-command setup
From the project root:
```powershell
cd task-3
.\run_all.ps1