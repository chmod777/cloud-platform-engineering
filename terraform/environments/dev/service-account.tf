resource "google_service_account" "mgmt_vm" {
  account_id   = "sa-mgmt-vm"
  display_name = "Management VM Service Account"
  description  = "Dedicated service account for the management VM"
}
