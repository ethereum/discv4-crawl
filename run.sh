#!/bin/bash

CRAWL_GIT_REPO="${CRAWL_GIT_REPO:-https://github.com/ethereum/discv4-dns-lists.git}"
CRAWL_GIT_BRANCH="${CRAWL_GIT_BRANCH:-master}"
CRAWL_GIT_PUSH="${CRAWL_GIT_PUSH:-false}"
CRAWL_GIT_USER="${CRAWL_GIT_USER:-crawler}"
CRAWL_GIT_EMAIL="${CRAWL_GIT_EMAIL:-crawler@localhost}"

CRAWL_DNS_DOMAIN="${CRAWL_DNS_DOMAIN:-nodes.example.local}"
CRAWL_TIMEOUT="${CRAWL_TIMEOUT:-30m}"
CRAWL_INTERVAL="${CRAWL_INTERVAL:-300}"
CRAWL_RUN_ONCE="${CRAWL_RUN_ONCE:-false}"
CRAWL_DNS_SIGNING_KEY="${CRAWL_DNS_SIGNING_KEY:-/secrets/key.json}"

CRAWL_DNS_PUBLISH_ROUTE53="${CRAWL_DNS_PUBLISH_ROUTE53-false}"
ROUTE53_ZONE_ID="${ROUTE53_ZONE_ID-}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID-}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY-}"

CRAWL_DNS_PUBLISH_CLOUDFLARE="${CRAWL_DNS_PUBLISH_CLOUDFLARE-false}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN-}"
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID-}"

INFLUXDB_METRICS_ENABLED="${INFLUXDB_METRICS_ENABLED:-false}"
INFLUXDB_URL="${INFLUXDB_URL:-http://localhost:8086}"
INFLUXDB_DB="${INFLUXDB_DB:-metrics}"
INFLUXDB_USER="${INFLUXDB_USER:-user}"
INFLUXDB_PASSWORD="${INFLUXDB_PASSWORD:-password}"

PROMETHEUS_METRICS_ENABLED="${PROMETHEUS_METRICS_ENABLED:-true}"
PROMETHEUS_METRICS_LISTEN="${PROMETHEUS_METRICS_LISTEN:-0.0.0.0:9100}"

prometheus_metrics_dir=$(mktemp -d)
set -xe

geth_src="$PWD/go-ethereum"

# Function definitions

git_update_repo() {
  upstream=$1
  repodir=$2
  branch=${3:-master}

  if [[ -d $repodir/.git ]]; then
    ( cd "$repodir"; git pull "$upstream"; git checkout "$branch" )
  else
    git clone --depth 1 --branch "$branch" "$upstream" "$repodir"
  fi
}

update_devp2p_tool() {
  git_update_repo https://github.com/ethereum/go-ethereum "$geth_src"
  ( cd "$geth_src" && go build ./cmd/devp2p )
}

filter_list() {
  network="$1"
  name="$2"
  shift 2

  mkdir -p "${name}.${network}.${CRAWL_DNS_DOMAIN}"
  devp2p nodeset filter all.json -eth-network "$network" $@ > "${name}.${network}.${CRAWL_DNS_DOMAIN}/nodes.json"
}

generate_list() {
  devp2p discv4 crawl -timeout "$CRAWL_TIMEOUT" all.json

  # Mainnet
  filter_list mainnet all   -limit 3000
  filter_list mainnet les   -limit 200  -les-server
  filter_list mainnet snap  -limit 500  -snap

  # Sepolia
  filter_list sepolia all   -limit 250
  filter_list sepolia les   -limit 25   -les-server
  filter_list sepolia snap  -limit 25   -snap

  # Holesky
  filter_list holesky all   -limit 250
  filter_list holesky snap  -limit 25   -snap
}

sign_lists() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      echo "" | devp2p dns sign "${D}" "$CRAWL_DNS_SIGNING_KEY"
    fi
  done
}

publish_dns_cloudflare() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      devp2p dns to-cloudflare -zoneid "$CLOUDFLARE_ZONE_ID" "${D}"
    fi
  done
}

publish_dns_route53() {
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      devp2p dns to-route53 -zone-id "$ROUTE53_ZONE_ID" "${D}"
    fi
  done
}

git_push_crawler_output() {
  if [ -n "$(git status --porcelain)" ]; then
    git add all.json ./*."${CRAWL_DNS_DOMAIN}"/*.json
    git commit --message "automatic update: crawl time $CRAWL_TIMEOUT"
    git push origin "$CRAWL_GIT_BRANCH"
  fi
}

publish_influx_metrics() {
  local status=$1
  echo "devp2p_discv4.dns_node_crawl_status value=${status}i" > metrics.txt
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      LEN=$(jq length < "${D}/nodes.json")
      echo "devp2p_discv4.dns_node_count,domain=${D} value=${LEN}i" >> metrics.txt
    fi
  done
  cat metrics.txt
  set +x
  curl -i -u "${INFLUXDB_USER}:${INFLUXDB_PASSWORD}" \
       -XPOST "${INFLUXDB_URL}/write?db=${INFLUXDB_DB}" --data-binary @metrics.txt
  set -x
  rm metrics.txt
}

init_prometheus_metrics() {
  go install -v github.com/projectdiscovery/simplehttpserver/cmd/simplehttpserver@v0.0.6
  simplehttpserver -listen "${PROMETHEUS_METRICS_LISTEN}" -path "${prometheus_metrics_dir}" -silent &
  publish_prometheus_metrics
}

publish_prometheus_metrics() {
  local status=$1
  prometheus_metrics_file="${prometheus_metrics_dir}/metrics"
  echo "devp2p_discv4_dns_nodes_crawl_status ${status}" > "${prometheus_metrics_file}"
  for D in *."${CRAWL_DNS_DOMAIN}"; do
    if [ -d "${D}" ]; then
      LEN=$(jq length < "${D}/nodes.json")
      echo "devp2p_discv4_dns_nodes{domain=\"${D}\"} ${LEN}" >> "${prometheus_metrics_file}"
    fi
  done
}

# Main execution

git config --global user.email "$CRAWL_GIT_EMAIL"
git config --global user.name "$CRAWL_GIT_USER"
git_update_repo "$CRAWL_GIT_REPO" output "$CRAWL_GIT_BRANCH"

PATH="$geth_src:$PATH"
cd output

if [ "$PROMETHEUS_METRICS_ENABLED" = true ] ; then
  init_prometheus_metrics
fi

while true
do
  # Initialize crawl status as success
  crawl_status=1

  # Pull changes from go-ethereum.
  update_devp2p_tool || crawl_status=0

  # Generate node lists
  generate_list || crawl_status=0

  # Sign lists
  if [ -f "$CRAWL_DNS_SIGNING_KEY" ]; then
    sign_lists || crawl_status=0
  fi

  # Push changes back to git repo
  if [ "$CRAWL_GIT_PUSH" = true ] ; then
    git_push_crawler_output || crawl_status=0
  fi

  # Publish DNS records
  if [ "$CRAWL_DNS_PUBLISH_CLOUDFLARE" = true ] ; then
    publish_dns_cloudflare || crawl_status=0
  fi
  if [ "$CRAWL_DNS_PUBLISH_ROUTE53" = true ] ; then
    publish_dns_route53 || crawl_status=0
  fi

  # Publish metrics
  if [ "$INFLUXDB_METRICS_ENABLED" = true ] ; then
    publish_influx_metrics $crawl_status
  fi
  if [ "$PROMETHEUS_METRICS_ENABLED" = true ] ; then
    publish_prometheus_metrics $crawl_status
  fi

  if [ "$CRAWL_RUN_ONCE" = true ] ; then
    echo "Ran once. Job is done. Exiting..."
    break
  fi

  # Wait for the next run
  echo "Waiting $CRAWL_INTERVAL seconds for the next run..."
  sleep "$CRAWL_INTERVAL"
done

# Kill all background jobs
kill "$(jobs -p)"
