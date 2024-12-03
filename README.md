# discv4-crawl

## Background

[Geth](https://github.com/ethereum/go-ethereum) now ships with an implementation of [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459). This EIP defines a way to put devp2p node lists behind a DNS name. There are a couple of things worth knowing about this system:

    EIP-1459 is intended to be a replacement for hard-coded bootstrap node lists that we maintain in Ethereum clients.
    This is a centralized system where all nodes configured with a certain name resolve subdomains of the name find bootstrap nodes.
    The node list is signed with a key which will be hard-coded into the client (i.e. geth) and which we should keep in a secure place.

To create suitable bootstrap node lists for all common networks, we have devised a scheme where software crawls the discovery DHT, then creates a list of all found nodes in JSON format. The crawler software can filter this list and has a built-in deployer that can install the DNS records.

You can read the [DNS Discovery Setup Guide](https://geth.ethereum.org/docs/developers/dns-discovery-setup) for more information about the discovery DHT crawler.

## Description

This repository contains the scripts used to automatically generate the list of nodes that are published to the multiple DNS zones. The node list is also automatically pushed to this repository.

## Running with docker



### Environment variables

Name | Default | Description
-----| ------- | -------
`CRAWL_GIT_REPO` | `https://github.com/ethereum/discv4-dns-lists.git` | Git repository `used to clone and push the node list
`CRAWL_GIT_BRANCH` | `master` | Git branch used for the fetch and push
`CRAWL_GIT_PUSH` | `false` | When set to `true`, it will push the node lists to the git repository
`CRAWL_GIT_USER` | `crawler` | Git username. Will appear in the commit messages.
`CRAWL_GIT_EMAIL` | `crawler@localhost` | Git email address. Will appear in the `commit messages.
`CRAWL_DNS_DOMAIN`| `nodes.example.local` | DNS domain suffix used for the directory structure
`CRAWL_TIMEOUT` | `30m` | The time spent crawling the discovery DHT
`CRAWL_INTERVAL` | `300` | Interval, in seconds, between multiple executions.
`CRAWL_RUN_ONCE` | `false` | Set to `true` if you only want to run the execution once.
`CRAWL_DNS_SIGNING_KEY` | `/secrets/key.json` | Path to the signing key. Won't sign if the file doesn't exist.
`CRAWL_DNS_PUBLISH_ROUTE53`| `false`| Publish the TXT records to a DNS zone on AWS Route53
`ROUTE53_ZONE_ID` | `` | Route53 DNS zone identifier. This is the zone where the records will be published to.
`AWS_ACCESS_KEY_ID` | `` | AWS access key
`AWS_SECRET_ACCESS_KEY` | `` | AWS secret access key
`CRAWL_DNS_PUBLISH_CLOUDFLARE` | `false` | Publish the TXT records to a DNS zone on Cloudflare
`CLOUDFLARE_API_TOKEN`| `` | API token used for the Cloudflare API
`CLOUDFLARE_ZONE_ID` | `` | Cloudflare DNS zone identifier. This is the zone where the records will be published to.
`INFLUXDB_METRICS_ENABLED` | `false` | Set to `true` if you want to send metrics to InfluxDB
`INFLUXDB_URL` | `http://localhost:8086` | Address of the InfluxDB API
`INFLUXDB_DB` | `metrics` | Database name
`INFLUXDB_USER` | `user` | Username for InfluxDB
`INFLUXDB_PASSWORD` | `password` | Password for InfluxDB
`PROMETHEUS_METRICS_ENABLED`| `true` | Enable prometheus metrics endpoint
`PROMETHEUS_METRICS_LISTEN` | `0.0.0.0:9100` | Server listening

### Building the image

```sh
$ docker build -t discv4-crawl .
```

### Run examples

Run the list generation and push the results to git via SSH:

```sh
$ docker run -it \
    -v "$HOME/.ssh/crawler:/root/.ssh" \  # Needed if you use git via SSH
    -v "$HOME/secrets/secret-signing-key.json:/secrets/key.json" \ # Only needed if you want to sign the node lists
    -e CRAWL_TIMEOUT=10m \ # Specify your custom timeout
    -e CRAWL_GIT_REPO=git@github.com:ethereum/discv4-dns-lists.git \ # Use SSH instead of HTTPS
    -e CRAWL_GIT_PUSH=true \ # Specify that we want to push the changes
    ghcr.io/ethereum/discv4-crawl:master
```
