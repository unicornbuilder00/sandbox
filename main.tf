terraform {
  required_version = ">= 1.6.0" # OpenTofu/Terraform compatible

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

########################################################
# Providers (env0-friendly)
########################################################
# Set credentials via env var:
#   GOOGLE_CREDENTIALS (service account JSON)
# Typical env0 variables you’ll set:
#   TF_VAR_project_id, TF_VAR_region, TF_VAR_org_id, TF_VAR_billing_account

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

########################################################
# Zero-change connectivity smoke checks
########################################################
# Who am I? (confirms auth works)
data "google_client_openid_userinfo" "me" {}

# Can the providers see the project?
data "google_project" "current" {
  project_id = var.project_id
}

output "whoami_email" {
  value       = data.google_client_openid_userinfo.me.email
  description = "Authenticated principal email (from GOOGLE_CREDENTIALS)."
}

output "project_number" {
  value       = data.google_project.current.number
  description = "Project number for the configured project_id."
}

########################################################
# OPTIONAL: Google Project Factory test
########################################################
# Flip TF_VAR_enable_project_factory=true in env0 to exercise the module.
module "project_factory" {
  count  = var.enable_project_factory ? 1 : 0
  source = "terraform-google-modules/project-factory/google"
  # Pin a major version you use in your org; adjust if needed.
  version = "~> 15.0"

  # Minimal required inputs
  name               = var.pf_project_name
  org_id             = var.org_id              # or set folder_id instead
  billing_account    = var.billing_account
  random_project_id  = true

  # Keep it lightweight; enables a couple of common APIs for sanity
  activate_apis = var.activate_apis

  # Good practice for new projects
  default_service_account = "deprivilege"

  # CI-friendly
  skip_gcloud_download = true

  # Prevent surprise deletions in experiments
  lien = false
}

output "pf_project_id" {
  value       = try(module.project_factory[0].project_id, null)
  description = "Project ID created by Project Factory (only when enabled)."
}

########################################################
# Variables with safe defaults
########################################################
variable "project_id" {
  description = "Existing GCP project to use for provider/data connectivity tests."
  type        = string
}

variable "region" {
  description = "Default region for tests."
  type        = string
  default     = "us-central1"
}

variable "enable_project_factory" {
  description = "If true, run a minimal Project Factory plan/apply to validate module wiring."
  type        = bool
  default     = false
}

variable "pf_project_name" {
  description = "Human-friendly name for the Project Factory-created project."
  type        = string
  default     = "env0-tofu-pf-smoketest"
}

variable "org_id" {
  description = "GCP Organization ID (required for Project Factory unless using folder_id)."
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID for the new project (e.g., 000000-000000-000000)."
  type        = string
  default     = ""
}

variable "activate_apis" {
  description = "APIs to activate in the Project Factory-created project."
  type        = list(string)
  default     = [
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
    "billingbudgets.googleapis.com"
  ]
}
