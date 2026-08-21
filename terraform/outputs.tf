output "vm_public_ip" {
  description = "IP công khai của VM (dùng cho GitHub Secret VM_HOST)"
  value       = google_compute_instance.mlops_vm.network_interface[0].access_config[0].nat_ip
}

output "bucket_name" {
  description = "Tên Cloud Storage Bucket (dùng cho GitHub Secret CLOUD_BUCKET)"
  value       = google_storage_bucket.mlops_bucket.name
}

output "service_account_email" {
  description = "Email của Service Account (dùng cho GitHub Secret GCP_SERVICE_ACCOUNT)"
  value       = google_service_account.mlops_sa.email
}

output "workload_identity_provider" {
  description = "WIF Provider ID (dùng cho GitHub Secret GCP_WORKLOAD_IDENTITY_PROVIDER)"
  value       = google_iam_workload_identity_pool_provider.github_provider.name
}

output "vm_user" {
  description = "Tên VM User (dùng cho GitHub Secret VM_USER)"
  value       = var.vm_user
}
