output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.platform_vpc.name
}

output "app_subnet" {
  description = "Application subnet CIDR"
  value       = google_compute_subnetwork.app_subnet.ip_cidr_range
}

output "mgmt_subnet" {
  description = "Management subnet CIDR"
  value       = google_compute_subnetwork.mgmt_subnet.ip_cidr_range
}
