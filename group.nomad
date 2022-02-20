// xxx - fights project.nomad's `ports_extra_http`
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
