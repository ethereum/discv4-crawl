# discv4-crawl

## Background

[Geth](https://github.com/ethereum/go-ethereum) now ships with an implementation of EIP-1459. This EIP defines a way to put devp2p node lists behind a DNS name. There are a couple of things worth knowing about this system:

    EIP-1459 is intended to be a replacement for hard-coded bootstrap node lists that we maintain in Ethereum clients.
    This is a centralized system where all nodes configured with a certain name resolve subdomains of the name find bootstrap nodes.
    The node list is signed with a key which will be hard-coded into the client (i.e. geth) and which we should keep in a secure place.

To create suitable bootstrap node lists for all common networks, we have devised a scheme where software crawls the discovery DHT, then creates a list of all found nodes in JSON format. The crawler software can filter this list and has a built-in deployer that can install the DNS records.

## Description

This repository contains the scripts used to automatically generate the list of nodes that are published to the multiple DNS zones. The node list is also automatically pushed to this repository.

## Environment variables

Name | Default | Purpose
-----| ------- | -------
CRAWL_TIMEOUT | `30m` | The time spent crawling the discovery DHT
CRAWL_GIT_REPO | `git@github.com:skylenet/discv4-crawl.git` | Git repository used to clone and push the node list
CRAWL_GIT_BRANCH | `master` | Git branch used for the fetch and push
CRAWL_GIT_USER | `crawler` | Git username. Will appear in the commit messages.
CRAWL_GIT_EMAIL | `crawler@localhost` | Git email address. Will appear in the commit messages.
CRAWL_DNS_SIGNING_KEY | `/secrets/key.json` | Path to the signing key. Won't sign if the file doesn't exist.

## Running with docker

Build the image

```sh
$ docker build -t disc4-crawl .
```

Run the list generation

```sh
$ docker run -it \
    -v "$HOME/.ssh/crawler:/root/.ssh" \  # Needed if you use git via SSH
    -v "$HOME/secrets/secret-signing-key.json:/secrets/key.json" \ # Only needed if you want to sign the node lists
    -e CRAWL_TIMEOUT=10m \ # Specify your custom timeout
    discv4-crawl
```
