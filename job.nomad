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

      config {
        image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
        network_mode = "local"
        ports = ["http"]
      }
    }
  }
}
