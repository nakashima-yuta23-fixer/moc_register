provider "azurerm" {
  # Azure Provider: Authenticating using a Service Principal with a Client Secret
  # Reference | https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret

  # client_id       = "" # Can also be set via `ARM_CLIENT_ID` environment variable.
  # client_secret   = "" # Can also be set via `ARM_CLIENT_SECRET` environment variable.
  # subscription_id = "" # Can also be set via `ARM_SUBSCRIPTION_ID` environment variable.
  # tenant_id       = "" # Can also be set via `ARM_TENANT_ID` environment variable.

  features {}
}
