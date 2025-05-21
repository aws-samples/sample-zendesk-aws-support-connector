variable "region" {
  description = "Region to deploy"
  type        = string
}

variable "zendesk_oauth_access_token" {
  description = "Zendesk API key"
  type        = string
}

variable "zendesk_subdomain" {
  description = "Zendesk subdomain"
  type        = string
}

variable "zendesk_admin_email" {
  description = "Zendesk admin email linked to the API key"
  type        = string
}

variable "bearer_token" {
  description = "Bearer token to be used by Zendesk webhooks"
  type        = string
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default     = {}
}

