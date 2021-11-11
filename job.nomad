dynamic "group" {
  for_each = ["${var.SLUG}-backend"]
  labels = ["${group.value}"]
  content {
    network {
      # you can omit `to = ..` to let nomad choose the port - that works, too :)
      port "http" { to = 5432 }
    }

    service {
      name = "${var.SLUG}-backend"
      port = "http"
      connect { native = true }
    }

    dynamic "task" {
      for_each = ["${var.SLUG}-backend"]
      labels = ["${group.value}"]
      content {
        driver = "docker"

        config {
          image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
          network_mode = "local"
          ports = ["http"]
          auth {
            server_address = "${var.CI_REGISTRY}"
            username = element([for s in [var.CI_R2_USER, var.CI_REGISTRY_USER] : s if s != ""], 0)
            password = element([for s in [var.CI_R2_PASS, var.CI_REGISTRY_PASSWORD] : s if s != ""], 0)
          }
        }
      }
    }
  }
}
