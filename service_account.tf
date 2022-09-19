resource "google_service_account" "tweeter-sa" {
  account_id   = "svc-tweeter-iocs"
  display_name = "Service Account for tweet ingestion."
}