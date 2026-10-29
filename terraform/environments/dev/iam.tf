resource "google_project_iam_member" "iap_access" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:hassensiad@gmail.com"
}

resource "google_project_iam_member" "os_login" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = "user:hassensiad@gmail.com"
}
