variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "genq-telemetry"
}

variable "grafana_otlp_endpoint" {
  description = "Grafana Cloud OTLP endpoint (e.g. https://otlp-gateway-prod-us-east-0.grafana.net)"
  type        = string
}

variable "grafana_instance_id" {
  description = "Grafana Cloud instance ID (numeric)"
  type        = string
}

variable "grafana_api_key" {
  description = "Grafana Cloud API key for OTLP ingest"
  type        = string
  sensitive   = true
}

variable "s3_retention_days" {
  description = "Days before S3 objects expire"
  type        = number
  default     = 365
}
