resource "google_pubsub_topic" "ioc-tweeter-ingest-trigger" {
  name = "ioc-tweeter-ingest-trigger"
}

resource "google_pubsub_topic" "ioc-tweeter-ingest-ps-schema" {
  name = "ioc-tweeter-ingest-ps-schema"

  depends_on = [google_pubsub_schema.tweet-with-epoch]
  schema_settings {
    schema   = google_pubsub_schema.tweet-with-epoch.id
    encoding = "JSON"
  }
}

resource "google_pubsub_subscription" "push-subscription-bq" {
  name  = "ioc-tweeter-ingest-ps-schema-bq"
  topic = google_pubsub_topic.ioc-tweeter-ingest-ps-schema.name

  bigquery_config {
    table               = "${var.project_id}:${google_bigquery_table.tweets.dataset_id}.${google_bigquery_table.tweets.table_id}"
    use_topic_schema    = true
    drop_unknown_fields = true
  }

}

resource "google_pubsub_schema" "tweet-with-epoch" {
  name       = "tweet-with-epoch"
  type       = "AVRO"
  definition = file("./schemas/tweet-with-epoch.json")
}

data "google_iam_policy" "pubsub-viewer" {
  binding {
    role = "roles/pubsub.subscriber"
    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}"
    ]
  }
}

data "google_iam_policy" "pubsub-publisher" {
  binding {
    role = "roles/pubsub.publisher"
    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}"
    ]
  }

  binding {
    role = "roles/pubsub.viewer"
    members = [
      "serviceAccount:${google_service_account.tweeter-sa.email}"
    ]
  }
}

resource "google_pubsub_topic_iam_policy" "publisher-schema-policy" {
  project     = data.google_project.project.name
  topic       = google_pubsub_topic.ioc-tweeter-ingest-ps-schema.name
  policy_data = data.google_iam_policy.pubsub-publisher.policy_data
}

resource "google_pubsub_topic_iam_policy" "policy" {
  project     = data.google_project.project.name
  topic       = google_pubsub_topic.ioc-tweeter-ingest-trigger.name
  policy_data = data.google_iam_policy.pubsub-viewer.policy_data
}