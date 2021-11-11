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
