# NOTE: *critically* you have to run this on each VM that hosts nomad docker containers *first*:
#   sudo docker network create local

# To find another container's port to talk to it, use for hostname: [TASKNAME].connect.consul
# and then to lookup, for example, `internetarchive-nomad-multiple-tasks-backend` port, either of:
#   dig +short internetarchive-nomad-multiple-tasks-backend.service.consul SRV |cut -f3 -d' '
#   wget -qO- 'http://consul.service.consul:8500/v1/catalog/service/internetarchive-nomad-multiple-tasks-backend?passing' |jq .
#
#
#  https://medium.com/@leshik/a-little-trick-with-docker-12686df15d58


variables {
  CI_REGISTRY = "registry.gitlab.com"
  CI_REGISTRY_IMAGE = "registry.gitlab.com/internetarchive/nomad-multiple-tasks"
  CI_COMMIT_REF_SLUG = "main"
  CI_COMMIT_SHA = "latest"

  SLUG = "internetarchive-nomad-multiple-tasks"
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


job "NOMAD_VAR_SLUG" {
  datacenters = ["dc1"]

  group "NOMAD_VAR_SLUG" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5000 }
      port "back" { to = 5432 }
    }

    service {
      task = "${var.SLUG}"
      name = "${var.SLUG}"
      port = "http"

      # connect { native = true }

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

        config {
          image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
          network_mode = "local"
          ports = ["http"]
        }
      }
    }


    service {
      task = "${var.SLUG}-backend"
      name = "${var.SLUG}-backend"
      port = "back"

      # connect { native = true }

      check {
        name     = "alive"
        type     = "tcp"
        port     = "back"
        timeout  = "10s"
        interval = "10s"
      }
    }

    dynamic "task" {
      for_each = ["${var.SLUG}-backend"]
      labels = ["${task.value}"]
      content {
        driver = "docker"

        config {
          image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
          network_mode = "local"
          ports = ["back"]
        }
      }
    }
  }
}
