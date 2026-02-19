################################
# 各リソースに共通する変数
################################
variable "customer_code" {
  description = "A short and unique code representing the customer or context of the resource. (e.g. courts, roster)"
  type        = string
}

variable "environment" {
  description = "The full environment name (e.g. development, staging, production)."
  type        = string

  validation {
    # このプロジェクトでは検証環境と本番環境のみ使用する。
    condition     = contains(["production", "verification"], var.environment)
    error_message = "This value must be production or verification."
  }
}

variable "environment_code" {
  description = "The short code representing the environment (e.g. dv, st, pr)"
  type        = string

  validation {
    # このプロジェクトでは検証環境と本番環境のみ使用する。
    condition     = contains(["pr", "ve"], var.environment_code)
    error_message = "This value must be pr or ve."
  }
}

variable "primary_location" {
  # Reference | https://learn.microsoft.com/en-us/azure/reliability/regions-list#azure-regions-list-1
  description = "The Azure official Programmatic name of primary region (e.g. japaneast, japanwest)."
  type        = string
  default     = "japaneast"

  validation {
    # このプロジェクトではリソースは原則国内リージョンに作成し、かつ、常時運用するリソースは東日本、DRリージョンを西日本とする。
    condition     = var.primary_location == "japaneast"
    error_message = "This value must japaneast"
  }
}

variable "primary_location_code" {
  # Reference | https://learn.microsoft.com/en-us/azure/reliability/regions-list#azure-regions-list-1
  description = "The short name representing Azure official Programmatic name of primary region (e.g. je, jw)."
  type        = string
  default     = "je"

  validation {
    # このプロジェクトではリソースは原則国内リージョンに作成し、かつ、常時運用するリソースは東日本、DRリージョンを西日本とする。
    condition     = var.primary_location_code == "je"
    error_message = "This value must je"
  }
}

variable "dr_location" {
  # Reference | https://learn.microsoft.com/en-us/azure/reliability/regions-list#azure-regions-list-1
  description = "The Azure official Programmatic name of DR region (e.g. japaneast, japanwest)."
  type        = string
  default     = "japanwest"

  validation {
    # このプロジェクトではリソースは原則国内リージョンに作成し、かつ、常時運用するリソースは東日本、DRリージョンを西日本とする。
    condition     = var.dr_location == "japanwest"
    error_message = "This value must japanwest"
  }
}

variable "dr_location_code" {
  # Reference | https://learn.microsoft.com/en-us/azure/reliability/regions-list#azure-regions-list-1
  description = "The short name representing Azure official Programmatic name of DR region (e.g. je, jw)."
  type        = string
  default     = "jw"

  validation {
    # このプロジェクトではリソースは原則国内リージョンに作成し、かつ、常時運用するリソースは東日本、DRリージョンを西日本とする。
    condition     = var.dr_location_code == "jw"
    error_message = "This value must jw"
  }
}


################################
# Jumpbox用のVMに関する変数
################################
variable "jumpbox_vm_admin_password" {
  description = "Jumpbox用のVMで使用するadminのパスワード"
  type        = string
  sensitive   = true
}
