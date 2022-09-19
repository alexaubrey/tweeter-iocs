resource "google_secret_manager_secret" "twitter-api-secret" {
  secret_id = "twitter-token"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "twitter-api-secret-version" {
  secret = google_secret_manager_secret.twitter-api-secret.id

  secret_data = var.tweeter-token
}

data "google_iam_policy" "secret_iam_policy" {
  binding {
    role = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}"
    ]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  project     = var.project_id
  secret_id   = google_secret_manager_secret.twitter-api-secret.id
  policy_data = data.google_iam_policy.secret_iam_policy.policy_data
}