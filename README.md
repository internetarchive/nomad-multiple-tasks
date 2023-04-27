# nomad-multiple-tasks

demo repo that deploys two+ related containers (eg: frontend + redis or DB, etc.)
which can talk to each other

example webapp (this repo): https://internetarchive-nomad-multiple-tasks.dev.archive.org/


## how to
From inside a container, to find another container's port to talk to it,
read the environment variable for the relevant named port.
For example, for a port named `backend`, you'd want to read this environment variable
which contains the IP address and port number of the backend service.
```
$NOMAD_ADDR_backend
```

Our port numbers and names get setup in our

[.gitlab-ci.yml](.gitlab-ci.yml)

here:
```yaml
  NOMAD_VAR_PORTS: '{ 5000 = "http", 5432 = "backend" }'
```
