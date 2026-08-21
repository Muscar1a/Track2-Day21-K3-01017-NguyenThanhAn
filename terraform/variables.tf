variable "project_id" {
  type        = string
  description = "Google Cloud Project ID của bạn"
}

variable "region" {
  type        = string
  description = "GCP Region (ví dụ: us-central1)"
  default     = "us-central1"
}

variable "zone" {
  type        = string
  description = "GCP Zone (ví dụ: us-central1-a)"
  default     = "us-central1-a"
}

variable "bucket_name" {
  type        = string
  description = "Tên Cloud Storage Bucket duy nhất trên toàn cầu (ví dụ: mlops-lab-wine-k3-an)"
}

variable "vm_user" {
  type        = string
  description = "Tên user trên Linux VM"
  default     = "ubuntu"
}

variable "ssh_public_key" {
  type        = string
  description = "Nội dung file public key SSH (~/.ssh/mlops_deploy.pub)"
}
