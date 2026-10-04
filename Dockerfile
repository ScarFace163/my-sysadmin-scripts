FROM ubuntu:22.04

RUN apt-get update \
    && apt-get install -y --no-install-recommends procps python3 \
    && rm -rf /var/lib/apt/lists/*

COPY script.sh /usr/local/bin/script.sh
COPY start-service.sh /usr/local/bin/start-service.sh
RUN chmod +x /usr/local/bin/script.sh /usr/local/bin/start-service.sh

WORKDIR /data
ENV LOG_FILE=/data/monitor.log

EXPOSE 8080
CMD ["/usr/local/bin/start-service.sh"]
