resource "google_storage_bucket" "maxmind-staging" {
  name          = "maxmind-staging"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket" "tweeter-ingestor-function-src" {
  name          = "tweeter-function"
  location      = var.region
  force_destroy = true
}

data "google_iam_policy" "gcs_policy" {
  binding {
    role = "roles/storage.admin"
    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}"
    ]
  }
}

resource "google_storage_bucket_iam_policy" "gcs_policy" {
  bucket      = google_storage_bucket.tweeter-ingestor-function-src.name
  policy_data = data.google_iam_policy.gcs_policy.policy_data
}

resource "google_storage_bucket_object" "archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.tweeter-ingestor-function-src.name
  source = "./src/function/function.zip"
}