#
#
# NOTE: this file is not used in any way and is just here to help show a more complete, but minimal, multi-container
#       jobspec end-to-end
#


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
      port "backend" { to = 5432 }
    }

    service {
      task = "${var.SLUG}"
      name = "${var.SLUG}"
      port = "http"

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
          ports = ["http"]
        }
      }
    }


    service {
      task = "${var.SLUG}-backend"
      name = "${var.SLUG}-backend"
      port = "backend"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "backend"
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
          ports = ["backend"]
        }
      }
    }
  }
}
