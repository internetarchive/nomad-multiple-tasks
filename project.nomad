# NOTE: *critically* you have to run this on each VM that hosts nomad docker containers *first*:
#   sudo docker network create local

# To find another container's port to talk to it, use for hostname: [TASKNAME].connect.consul
# and then to lookup, for example, `internetarchive-nomad-multiple-tasks-backend` port, either of:
#   dig +short internetarchive-nomad-multiple-tasks-backend.service.consul SRV |cut -f3 -d' '
#   wget -qO- 'http://consul.service.consul:8500/v1/catalog/service/internetarchive-nomad-multiple-tasks-backend?passing' |jq .
#
#
#  https://medium.com/@leshik/a-little-trick-with-docker-12686df15d58


# Variables used below and their defaults if not set externally
variables {
  # These all pass through from GitLab [build] phase.
  # Some defaults filled in w/ example repo "bai" in group "internetarchive"
  # (but all 7 get replaced during normal GitLab CI/CD from CI/CD variables).
  CI_REGISTRY = "registry.gitlab.com"                       # registry hostname
  CI_REGISTRY_IMAGE = "registry.gitlab.com/internetarchive/bai"  # registry image location
  CI_COMMIT_REF_SLUG = "master"                             # branch name, slugged
  CI_COMMIT_SHA = "latest"                                  # repo's commit for current pipline
  CI_PROJECT_PATH_SLUG = "internetarchive-bai"              # repo and group it is part of, slugged

  # NOTE: if repo is public, you can ignore these next 4 registry related vars
  CI_REGISTRY_USER = ""                                     # set for each pipeline and ..
  CI_REGISTRY_PASSWORD = ""                                 # .. allows pull from private registry
  # optional (but suggested!) CI/CD group or project vars:
  CI_R2_USER = ""                                           # optional more reliable alternative ..
  CI_R2_PASS = ""                                           # .. to 1st user/pass (see README.md)


  # This autogenerates from https://gitlab.com/internetarchive/nomad/-/blob/master/.gitlab-ci.yml
  # & normally has "-$CI_COMMIT_REF_SLUG" appended, but is omitted for "main" or "master" branches.
  # You should not change this.
  SLUG = "internetarchive-bai"


  # The remaining vars can be optionally set/overriden in a repo via CI/CD variables in repo's
  # setting or repo's `.gitlab-ci.yml` file.
  # Each CI/CD var name should be prefixed with 'NOMAD_VAR_'.

  # default 300 MB
  MEMORY = 300
  # default 100 MHz
  CPU =    100

  # A repo can set this to "tcp" - can help for debugging 1st deploy
  CHECK_PROTOCOL = "http"
  # What path healthcheck should use and require a 200 status answer for succcess
  CHECK_PATH = "/"
  # Allow individual, periodic healthchecks this much time to answer with 200 status
  CHECK_TIMEOUT = "2s"
  # Dont start first healthcheck until container up at least this long (adjust for slow startups)
  HEALTH_TIMEOUT = "20s"

  # How many running containers should you deploy?
  # https://learn.hashicorp.com/tutorials/nomad/job-rolling-update
  COUNT = 1

  # Pass in "ro" or "rw" if you want an NFS /home/ mounted into container, as ReadOnly or ReadWrite
  HOME = ""

  NETWORK_MODE = "bridge"

  # only used for github repos
  CI_GITHUB_IMAGE = ""

  CONSUL_PATH = "/usr/bin/consul"

  FORCE_PULL = false

  # There are more variables immediately after this - but they are "lists" or "maps" and need
  # special definitions to not have defaults or overrides be treated as strings.
}

# Persistent Volume(s).  To enable, coordinate a free slot with your nomad cluster administrator
# and then set like, for PV slot 3 like:
#   NOMAD_VAR_PV='{ pv3 = "/pv" }'
#   NOMAD_VAR_PV='{ pv9 = "/bitnami/wordpress" }'
variable "PV" {
  type = map(string)
  default = {}
}

variable "PORTS" {
  # You must have at least one key/value pair, with a single value of 'http'.
  # Each value is a string that refers to your port later in the project jobspec.
  #
  # Note: these are all public ports, right out to the browser.
  #
  # Note: for a single *nomad cluster* -- anything not 5000 must be
  #       *unique* across *all* projects deployed there.
  #
  # Note: use -1 for your port to tell nomad & docker to *dynamically* assign you a random high port
  #       then your repo can read the environment variable: NOMAD_PORT_http upon startup to know
  #       what your main daemon HTTP listener should listen on.
  #
  # Note: if your port *only* talks TCP directly (or some variant of it, like IRC) and *not* HTTP,
  #       then make your port number (key) *negative AND less than -1*.
  #       Don't worry -- we'll use the abs() of it;
  #       negative numbers makes them easily identifiable and partition-able below ;-)
  #
  # Examples:
  #   NOMAD_VAR_PORTS='{ 5000 = "http" }'
  #   NOMAD_VAR_PORTS='{ -1 = "http" }'
  #   NOMAD_VAR_PORTS='{ 5000 = "http", 666 = "cool-ness" }'
  #   NOMAD_VAR_PORTS='{ 8888 = "http", 8012 = "backend", 7777 = "extra-service" }'
  #   NOMAD_VAR_PORTS='{ 5000 = "http", -7777 = "irc" }'
  type = map(string)
  default = { 5000 = "http" }
}

variable "HOSTNAMES" {
  # This autogenerates from https://gitlab.com/internetarchive/nomad/-/blob/master/.gitlab-ci.yml
  # but you can override to 1 or more custom hostnames if desired, eg:
  #   NOMAD_VAR_HOSTNAMES='["www.example.com", "site.example.com"]'
  type = list(string)
  default = ["group-project-branch-slug.example.com"]
}

variable "BIND_MOUNTS" {
  # Pass in a list of [host VM => container] direct pass through of readonly volumes, eg:
  #   NOMAD_VAR_BIND_MOUNTS='[{type = "bind", readonly = true, source = "/usr/games", target = "/usr/games"}]'
  type = list(map(string))
  default = []
}

variable "PG" {
  # Setup a postgres DB like NOMAD_VAR_PG='{ 5432 = "db" }' - or override port num if desired
  type = map(string)
  default = {}
}

variable "NOMAD_SECRETS" {
  # this is automatically populated with NOMAD_SECRET_ env vars by @see .gitlab-ci.yml
  type = map(string)
  default = {}
}


variable "NOT_PV" {
  # this is temporary until NFS server is setup for persistent volumes
  type = list(string)
  default = ["not pv"]
}


locals {
  # Ignore all this.  really :)
  job_names = [ "${var.SLUG}" ]

  # Copy hashmap, but remove map key/val for the main/default port (defaults to 5000).
  # Then split hashmap in two: one for HTTP port mappings; one for TCP (only; rare) port mappings.
  ports_main       = {for k, v in var.PORTS:                 k  => v  if v == "http"}
  ports_extra_tmp  = {for k, v in var.PORTS:                 k  => v  if v != "http"}
  ports_extra_http = {for k, v in local.ports_extra_tmp:     k  => v  if k > -2}
  ports_extra_tcp  = {for k, v in local.ports_extra_tmp: abs(k) => v  if k < -1}

  # Now create a hashmap of *all* ports to be used, but abs() any portnumber key < -1
  ports_all = merge(local.ports_main, local.ports_extra_http, local.ports_extra_tcp, var.PG, {})

  # NOTE: 2rd arg is hcl2 quirk needed in case first two args are empty maps as well
  pvs = merge(var.PV, {})

  # Make it so that later we can constrain deploy to server kind of _either_ pv or !pv kind server.
  # If PV is in use, constrain deployment to the single "pv" node in the cluster.
  kinds = concat([for k in keys(local.pvs): "pv"])
  # So if local.kinds is empty list (the default), set this to ["not pv"]; else set to []
  kinds_not = slice(var.NOT_PV, 0, min(length(var.NOT_PV), max(0, (1 - length(local.kinds)))))

  # Effectively use CI_GITHUB_IMAGE if set, otherwise use GitLab vars interpolated string
  docker_image = element([for s in [var.CI_GITHUB_IMAGE, "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"] : s if s != ""], 0)

  # GitLab docker login user/pass are pretty unstable.  If admin has set `..R2..` keys in
  # the group [Settings] [CI/CD] [Variables] - then use deploy token-based alternatives.
  # Effectively use CI_R2_* variant if set; else use CI_REGISTRY_* PAIR
  docker_user = [for s in [var.CI_R2_USER, var.CI_REGISTRY_USER    ] : s if s != ""]
  docker_pass = [for s in [var.CI_R2_PASS, var.CI_REGISTRY_PASSWORD] : s if s != ""]
  # Make [""] (array of length 1, val empty string) if all docker password vars are ""
  docker_no_login = [for s in [join("", [var.CI_R2_PASS, var.CI_REGISTRY_PASSWORD])]: s if s == ""]

  # If job is using secrets and CI/CD Variables named like "NOMAD_SECRET_*" then set this
  # string to a KEY=VAL line per CI/CD variable.  If job is not using secrets, set to "".
  kv = join("\n", [for k, v in var.NOMAD_SECRETS : join("", concat([k, "='", v, "'"]))])
}


# VARS.NOMAD--INSERTS-HERE


job "NOMAD_VAR_SLUG" {
  datacenters = ["dc1"]

  group "NOMAD_VAR_SLUG" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5000 }
    }

    service {
      name = "${var.SLUG}"
      port = "http"

      connect { native = true }

      # tags (for load balancer external name entries) & check are only difference between 2 groups
      tags = concat([for HOST in var.HOSTNAMES :
        "urlprefix-${HOST}:443/"], [for HOST in var.HOSTNAMES :
        "urlprefix-${HOST}:80/ redirect=308,https://${HOST}/"])

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        timeout  = "10s"
        interval = "10s"
      }
    }

    dynamic "task" {
      for_each = ["${var.SLUG}"]
      labels = ["${task.value}"]
      content {
        driver = "docker"

        env {
          # daemon reads this to know what port to listen on
          PORT = "${NOMAD_PORT_http}"
          # convenience var you can copy/paste in the other container, to talk to us
          WGET = "wget -qO- ${NOMAD_TASK_NAME}.connect.consul:${NOMAD_PORT_http}"
        }

        config {
          image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
          network_mode = "local"
          ports = ["http"]
        }
      }
    }
  }


  group "NOMAD_VAR_SLUG-backend" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5432 }
    }

    service {
      name = "${var.SLUG}-backend"
      port = "http"

      connect { native = true }

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        timeout  = "10s"
        interval = "10s"
      }
    }

    dynamic "task" {
      for_each = ["${var.SLUG}-backend"]
      labels = ["${task.value}"]
      content {
        driver = "docker"

        env {
          # daemon reads this to know what port to listen on
          PORT = "${NOMAD_PORT_http}"
          # convenience var you can copy/paste in the other container, to talk to us
          WGET = "wget -qO- ${NOMAD_TASK_NAME}.connect.consul:${NOMAD_PORT_http}"
        }

        config {
          image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
          network_mode = "local"
          ports = ["http"]
        }
      }
    }
  }
}
