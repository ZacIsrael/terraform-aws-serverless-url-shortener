# Exposes the deployed API Gateway endpoint for API testing and client access.
output "api_endpoint" {
  description = "Base URL of the deployed URL shortener HTTP API."
  value       = module.url_shortener.api_endpoint
}
