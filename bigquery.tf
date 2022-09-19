resource "google_bigquery_dataset" "iocs" {
  dataset_id  = "iocs"
  description = "BigQuery data set to hold tables with IOCs."
  location    = var.region
}

resource "google_bigquery_dataset" "maxmind" {
  dataset_id  = "maxmind"
  description = "BigQuery data set to hold tables for MaxMind enrichment."
  location    = var.region
}

resource "google_bigquery_table" "tweets" {
  dataset_id          = google_bigquery_dataset.iocs.dataset_id
  table_id            = "tweets"
  schema              = file("./schemas/tweets.json")
  deletion_protection = false
}

resource "google_bigquery_table" "indicators" {
  dataset_id          = google_bigquery_dataset.iocs.dataset_id
  table_id            = "indicators"
  deletion_protection = false
}

data "google_iam_policy" "iocs_owner" {
  binding {
    role = "roles/bigquery.dataOwner"

    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}",
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
    ]
  }
}

resource "google_bigquery_dataset_iam_policy" "iocs_iam" {
  dataset_id  = google_bigquery_dataset.iocs.dataset_id
  policy_data = data.google_iam_policy.iocs_owner.policy_data
}

# Enrichment query with MaxMind
resource "google_bigquery_data_transfer_config" "query_config" {

  display_name           = "enrich_tweets_with_maxmind"
  location               = var.region
  data_source_id         = "scheduled_query"
  schedule               = "every 15 minutes"
  destination_dataset_id = google_bigquery_dataset.iocs.dataset_id
  service_account_name   = google_service_account.tweeter-sa.email
  params = {
    destination_table_name_template = google_bigquery_table.indicators.table_id
    write_disposition               = "WRITE_APPEND"
    query                           = file("./src/batch_queries/extract_indicators.sql")
  }
}