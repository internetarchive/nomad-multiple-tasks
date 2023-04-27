task "backend" {
  driver = "docker"

  config {
    image = "${var.CI_REGISTRY_IMAGE}/${var.CI_COMMIT_REF_SLUG}:${var.CI_COMMIT_SHA}"
    ports = ["backend"]
  }
}
