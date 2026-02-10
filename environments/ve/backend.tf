terraform {
  backend "azurerm" {
    # Authorized by Access Key
    # Reference | https://developer.hashicorp.com/terraform/language/backend/azurerm#access-key
    # access_key           = "" # Can also be set via `ARM_ACCESS_KEY` environment variable.
    # storage_account_name = "" # Can be passed via `-backend-config=`"storage_account_name=<storage account name>"` in the `init` command.
    # container_name       = "" # Can be passed via `-backend-config=`"container_name=<container name>"` in the `init` command.
    # key                  = "" # Can be passed via `-backend-config=`"key=<blob key name>"` in the `init` command.
  }
}
