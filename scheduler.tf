resource "google_cloud_scheduler_job" "job" {
  name        = "trigger-twitter-ingestor"
  description = "Triggers twitter-ingestor cloud function"
  schedule    = "*/10 * * * *"

  pubsub_target {
    topic_name = google_pubsub_topic.ioc-tweeter-ingest-trigger.id
    data       = base64encode("trigger-function")
  }
}