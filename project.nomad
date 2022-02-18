variables {
  CI_COMMIT_REF_SLUG = "main"
  CI_COMMIT_SHA = "latest"
  CI_REGISTRY = "registry.archive.org"
  CI_REGISTRY_IMAGE = "registry.archive.org/www/sentry"
}

variable "HOSTNAMES" {
  type = list(string)
  default = ["internetarchive-nomad-multiple-tasks.dev.archive.org"]
}

variable "NOMAD_SECRETS" {
  # this is automatically populated with NOMAD_SECRET_ env vars by @see .gitlab-ci.yml
  type = map(string)
  default = {}
}


# NOTE: *critically* you have to run this on each VM that hosts nomad docker containers *first*:
#   sudo docker network create local

# To find another container's port to talk to it, use for hostname: [TASKNAME].connect.consul
# and then to lookup, for example, `internetarchive-nomad-multiple-tasks-backend` port, either of:
#   dig +short internetarchive-nomad-multiple-tasks-backend.service.consul SRV |cut -f3 -d' '
#   wget -qO- 'http://consul.service.consul:8500/v1/catalog/service/internetarchive-nomad-multiple-tasks-backend?passing' |jq .
#
#
#  https://medium.com/@leshik/a-little-trick-with-docker-12686df15d58


job "internetarchive-nomad-multiple-tasks" {
  datacenters = ["dc1"]

  group "internetarchive-nomad-multiple-tasks" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5000 }
    }

    service {
      name = "internetarchive-nomad-multiple-tasks"
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

    task "internetarchive-nomad-multiple-tasks" {
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


  group "internetarchive-nomad-multiple-tasks-backend" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5432 }
    }

    service {
      name = "internetarchive-nomad-multiple-tasks-backend"
      port = "http"

      connect { native = true }
    }

    task "internetarchive-nomad-multiple-tasks-backend" {
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
