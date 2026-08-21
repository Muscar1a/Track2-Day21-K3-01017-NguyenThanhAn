terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. Cloud Storage Bucket cho DVC & Model
resource "google_storage_bucket" "mlops_bucket" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true
}

# 2. Service Account cho DVC & VM
resource "google_service_account" "mlops_sa" {
  account_id   = "mlops-lab-sa"
  display_name = "MLOps Lab Service Account"
}

# Cấp quyền objectAdmin trên bucket (nguyên tắc quyền tối thiểu)
resource "google_storage_bucket_iam_member" "sa_storage_admin" {
  bucket = google_storage_bucket.mlops_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.mlops_sa.email}"
}

# 3. Workload Identity Federation (Xác thực GitHub Actions không cần Service Account Key)
resource "google_iam_workload_identity_pool" "github_pool" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  disabled                  = false
}

resource "google_iam_workload_identity_pool_provider" "github_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub Provider"
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository_owner != ''"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif_sa_user" {
  service_account_id = google_service_account.mlops_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_pool.name}/*"
}

# 4. Firewall mở port 22 (SSH) và port 8000 (FastAPI Inference API)
resource "google_compute_firewall" "allow_mlops_serve" {
  name    = "allow-mlops-serve"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "8000"]
  }

  target_tags   = ["mlops-serve"]
  source_ranges = ["0.0.0.0/0"]
}

# 5. Máy chủ ảo Cloud VM (e2-micro - Cấu hình tối thiểu / Free Tier GCP, Ubuntu 22.04 LTS)
resource "google_compute_instance" "mlops_vm" {
  name                      = "mlops-serve"
  machine_type              = "e2-micro"
  zone                      = var.zone
  tags                      = ["mlops-serve"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      type  = "pd-standard"
      size  = 10
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Cấp External IP công khai
    }
  }

  # Gắn Service Account trực tiếp vào VM -> Không cần file sa-key.json trên VM!
  service_account {
    email  = google_service_account.mlops_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.vm_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    fallocate -l 1G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

    sudo apt update -y
    sudo apt install -y python3-pip
    pip3 install fastapi==0.111.0 uvicorn==0.29.0 scikit-learn==1.4.2 joblib==1.4.2 google-cloud-storage==2.16.0
    mkdir -p /home/${var.vm_user}/models /home/${var.vm_user}/src
    chown -R ${var.vm_user}:${var.vm_user} /home/${var.vm_user}/models /home/${var.vm_user}/src
  EOF
}
