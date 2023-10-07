FROM golang:1.21

ENV CRAWL_GIT_REPO=https://github.com/skylenet/discv4-dns-lists.git \
    CRAWL_GIT_BRANCH=master \
    CRAWL_GIT_PUSH=false \
    CRAWL_GIT_USER=crawler \
    CRAWL_GIT_EMAIL=crawler@localhost \
    CRAWL_DNS_DOMAIN=nodes.example.local \
    CRAWL_TIMEOUT=30m \
    CRAWL_INTERVAL=300 \
    CRAWL_RUN_ONCE=false \
    CRAWL_DNS_SIGNING_KEY=/secrets/key.json \
    CRAWL_DNS_PUBLISH_ROUTE53=false \
    ROUTE53_ZONE_ID="" \
    AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    CRAWL_DNS_PUBLISH_CLOUDFLARE=false \
    CLOUDFLARE_API_TOKEN="" \
    CLOUDFLARE_ZONE_ID="" \
    INFLUXDB_METRICS_ENABLED=false \
    INFLUXDB_URL=http://localhost:8086 \
    INFLUXDB_DB=metrics \
    INFLUXDB_USER=user \
    INFLUXDB_PASSWORD=password \
    PROMETHEUS_METRICS_ENABLED=true \
    PROMETHEUS_METRICS_LISTEN=0.0.0.0:9100

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl jq \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 9100
WORKDIR /crawler
ADD run.sh .
CMD ["./run.sh"]
