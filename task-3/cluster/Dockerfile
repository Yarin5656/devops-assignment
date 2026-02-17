FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      apache2 \
      corosync \
      pacemaker \
      crmsh \
      pcs \
      resource-agents \
      curl \
      iproute2 \
      net-tools \
      procps \
      iputils-ping && \
    rm -rf /var/lib/apt/lists/*

COPY files/corosync.conf /etc/corosync/corosync.conf
COPY files/apache-ports.conf /etc/apache2/ports.conf
COPY files/apache-site.conf /etc/apache2/sites-available/000-default.conf
COPY files/index.html /var/www/html/index.html
COPY files/start-cluster.sh /usr/local/bin/start-cluster.sh
COPY files/bootstrap_cluster.sh /opt/bootstrap/bootstrap_cluster.sh

RUN chmod +x /usr/local/bin/start-cluster.sh /opt/bootstrap/bootstrap_cluster.sh && \
    sed -i 's/\r$//' /usr/local/bin/start-cluster.sh /opt/bootstrap/bootstrap_cluster.sh && \
    a2enmod headers status && \
    a2dissite 000-default >/dev/null 2>&1 || true && \
    a2ensite 000-default >/dev/null 2>&1 || true

CMD ["/usr/local/bin/start-cluster.sh"]
