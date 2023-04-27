# NOTE: this file is not used in any way and is just here to help show a more complete, but minimal,
#       multi-container jobspec end-to-end

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


job "NOMAD_VAR_SLUG" {
  datacenters = ["dc1"]

  group "NOMAD_VAR_SLUG" {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5000 }
      port "backend" { to = 5432 }
    }

    task "http" {
      driver = "docker"
      config {
        image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
        ports = ["http"]
      }
    }

    task "backend" {
      driver = "docker"
      config {
        image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
        ports = ["backend"]
      }
    }

    service {
      task = "http"
      name = "${var.SLUG}"
      port = "http"

      # tags (for load balancer external name entries)
      tags = [for HOST in var.HOSTNAMES: "https://${HOST}"]

      check {
        port     = "http"
        name     = "alive"
        type     = "tcp"
        timeout  = "10s"
        interval = "10s"
      }
    }

    service {
      task = "backend"
      name = "${var.SLUG}--backend"
      port = "backend"

      # no tags (for load balancer external name entries) since backend isn't exposed to browser

      check {
        port     = "backend"
        name     = "alive"
        type     = "tcp"
        timeout  = "10s"
        interval = "10s"
      }
    }
  }
}
