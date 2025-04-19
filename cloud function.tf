#health check monitoring cloud function
module "dr-health-check-cf" {
  source      = "app.terraform.io/fig-tlz/live-cloud-function-gen2/google"
  version     = "1.0.4"
  project_id  = local.project_id
  region      = var.region
  name        = var.health_check_cf_name
  bucket_name = module.dr-codes-bucket.name
  bundle_config = {
    source_dir  = "./dr-codes/health_check_cloud_function"
    output_path = "dr-hc-cf.zip"
  }
#   bucket_config = {
#      location = "us-east4"
#      lifecycle_delete_age_days = 365
#   }
  function_config = {
    entry_point        = "pubsubHandler"
    available_memory   = "256Mi"
    available_cpu      = "167m"
    runtime            = "nodejs22"
    timeout_seconds    = 540
    max_instance_count = 3
    min_instance_count = 0
    max_instance_request_concurrency = 1
  }
  runtime_environment_variables = {
      "PUBSUB_TOPIC_ID" = lookup(var.health_check_cf_runtime_env_values,"pubsub_topic_id",module.failover-pubsub-topic.name) #"dr-failover-topic"
      "LOAD_BALANCER_HEALTH_CHECK_URL" = lookup(var.health_check_cf_runtime_env_values,"load_balancer_health_check_url")
      "PROJECT_ID" = lookup(var.health_check_cf_runtime_env_values,"project_id","${var.project_id}")
  }
  # vpc_connector = {
  #   create          = false
  #   name            = "mrdr-east4-vpc-connector" 
  #   egress_settings = "ALL_TRAFFIC" #"PRIVATE_RANGES_ONLY"
  # }
  service_account_create = false
  service_account        =  module.mrdr-sa.email
  ingress_settings       = "ALLOW_INTERNAL_ONLY"
  trigger_config = {
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = module.healthcheck-pubsub-topic.id 
    trigger_region = var.region
    service_account_email = module.mrdr-sa.email
  }
#   docker_repository_id   = google_artifact_registry_repository.servicedesk_repository.id
}


# failover orchestrator function
module "dr-failover-cf" {
  source      = "app.terraform.io/fig-tlz/live-cloud-function-gen2/google"
  version     = "1.0.4"
  project_id  = var.project_id
  region      = var.region
  name        = var.failover_cf_name
  bucket_name = module.dr-codes-bucket.name   
  bundle_config = {
    source_dir  = "./dr-codes/dr-orchestrator"
    output_path = "dr-orchestrator-cf.zip"
  }
#   bucket_config = {
#      location = "us-east4"
#      lifecycle_delete_age_days = 365
#   }
  function_config = {
    entry_point        = "trigger_jenkins_pipeline"
    available_memory   = "256Mi"
    available_cpu      = "167m"
    runtime            = "python312"
    timeout_seconds    = 540
    max_instance_count = 3
    min_instance_count = 0
    max_instance_request_concurrency = 1
  }
  runtime_environment_variables = {
      "JENKINS_URL" = lookup(var.failover_cf_runtime_env_values,"jenkins_url")
      "JENKINS_JOB_NAME" = lookup(var.failover_cf_runtime_env_values,"jenkins_job_name")
      "JENKINS_USER" = lookup(var.failover_cf_runtime_env_values,"jenkins_user")
      "JENKINS_TOKEN" = lookup(var.failover_cf_runtime_env_values,"jenkins_token")
  }
  vpc_connector = {
    create          = false
    name            = var.vpc_connector 
    egress_settings = "ALL_TRAFFIC" 
  }
  trigger_config = {
    event_type = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = module.failover-pubsub-topic.id
    trigger_region = var.region
    service_account_email = module.mrdr-failover-sa.email
  }
  service_account_create = false
  service_account        =  module.mrdr-failover-sa.email
  ingress_settings       = "ALLOW_INTERNAL_ONLY"
#   docker_repository_id   = google_artifact_registry_repository.servicedesk_repository.id
}
