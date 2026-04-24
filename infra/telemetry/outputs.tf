output "api_endpoint" {
  description = "OTLP/HTTP endpoint URL — set this as telemetry.endpoint_url in config/default.toml"
  value       = aws_apigatewayv2_api.telemetry.api_endpoint
}

output "s3_bucket" {
  description = "S3 bucket name for compressed telemetry storage"
  value       = aws_s3_bucket.telemetry.id
}
