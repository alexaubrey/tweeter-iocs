resource "google_cloudfunctions_function" "tweet-ingestor" {
  name        = "twitter-ingestor"
  description = "Send new tweets to Pub/Sub"
  runtime     = "python310"

  source_archive_bucket = google_storage_bucket.tweeter-ingestor-function-src.name
  source_archive_object = google_storage_bucket_object.archive.name
  entry_point           = "main"

  service_account_email = google_service_account.tweeter-sa.email

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.ioc-tweeter-ingest-trigger.name
  }

  secret_environment_variables {
    key     = "TWEET_TOKEN"
    secret  = google_secret_manager_secret.twitter-api-secret.secret_id
    version = "latest"
  }

  environment_variables = {
    GOOGLE_PROJECT_ID   = var.project_id
    GOOGLE_DATASET_ID   = "iocs"
    GOOGLE_TABLE_ID     = "tweets"
    GOOGLE_PUBSUB_TOPIC = "ioc-tweeter-ingest-ps-schema"
  }
}