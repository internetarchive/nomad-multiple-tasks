# nomad-multiple-tasks

demo repo that deploys two+ related containers (eg: frontend + redis or DB, etc.)
which can talk to each other

example webapp (this repo): https://internetarchive-nomad-multiple-tasks.dev.archive.org/

## Prerequisites

NOTE: *critically* your nomad cluster admin has to run this on each VM that hosts nomad docker containers *first*:

```sh
sudo docker network create local
```


## Usage
From inside a container, to find another container's port to talk to it, use for hostname:
```
[TASKNAME].connect.consul
```
and then to lookup, for example, `internetarchive-nomad-multiple-tasks-backend` port, either of:
```
dig +short internetarchive-nomad-multiple-tasks-backend.service.consul SRV |cut -f3 -d' '
```
or
```
wget -qO- 'http://consul.service.consul:8500/v1/catalog/service/internetarchive-nomad-multiple-tasks-backend?passing' |jq .
```

You can then talk to the "backend" container, if it is REST HTTP, eg:
```
wget -qO- internetarchive-nomad-multiple-tasks-backend.connect.consul:[PORT-FROM-ABOVE]"

```


## References, Links
- https://medium.com/@leshik/a-little-trick-with-docker-12686df15d58
