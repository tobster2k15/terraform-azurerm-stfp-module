## Start Naming variables ## 
variable "business_unit" {
  description = "Business unit"
  type        = string
  default     = ""
}

variable "usecase" {
  description = "Usecase"
  type        = string
  default     = "sftp"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prd"
}

variable "region" {
  type        = string
  description = "The desired Azure region for the pool. See also var.region_prefix_map."
  validation {
    condition = anytrue([
      lower(var.region) == "ne",
      lower(var.region) == "we"
    ])
    error_message = "Please select one of the approved regions:ne(northeurope) or we (westeurope)."
  }
}

variable "resource_group_location" {
  description = "Resource Group Location"
  type        = string
  default     = ""
}

variable "region_prefix_map" {
  type        = map(any)
  description = "A list of prefix strings to concat in locals. Can be replaced or appended."
  default = {
    westeurope       = "we"
    northeurope      = "ne"
  }
}
### End Naming Variables ###
variable "tags" {
  type        = map(any)
  description = "The tags for the virtual machines and their subresources."
  default     = { Warning = "No tags" }
}
### Start Network Variables ###

variable "private_endpoint_enabled" {
  description = "Enable private endpoint"
  type        = bool
  default     = false
}

variable "address_space" {
  description = "Address space"
  type        = list(string)
  default     = ["10.0.0.0/16"]
  }

variable "address_prefix" {
  description = "Address prefixes"
  type        = list(string)
  default     = ["10.0.1.0/24"]
  }

### End Network Variables ###

### Start Storage Account Variables ###
variable "share_size" {
  description = "Share size"
  type        = string
  default     = "50"
}

variable "st_name" {
  description = "Name of the storage account"
  type        = string
  default     = ""
}

variable "st_account_kind" {
  description = "Kind of the storage account"
  type        = string
  default     = "StorageV2"
}

variable "st_account_tier" {
  description = "Tier of the storage account"
  type        = string
  default     = "Standard"
}

variable "st_replication" {
  description = "Replication type of the storage account"
  type        = string
  default     = "LRS"
}
### End Storage Account Variables ###
variable "users" {
  description = "List of local SFTP user objects."
  type = list(object({
    name                 = string
    home_directory       = optional(string)
    ssh_key_enabled      = optional(bool, true)
    ssh_password_enabled = optional(bool)
    permissions_scopes = list(object({
      target_container = string
      permissions      = optional(list(string), ["All"])
    }))
    ssh_authorized_keys = optional(list(object({
      key         = string
      description = optional(string)
    })), [])
  }))
}

