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
  description = "The Azure region where the resources will be deployed."
  validation {
    condition = anytrue([
      lower(var.region) == "northcentralus",
      lower(var.region) == "southcentralus",
      lower(var.region) == "westcentral",
      lower(var.region) == "centralus",
      lower(var.region) == "westus",
      lower(var.region) == "eastus",
      lower(var.region) == "northeurope",
      lower(var.region) == "westeurope",
      lower(var.region) == "norwayeast",
      lower(var.region) == "norwaywest",
      lower(var.region) == "swedencentral",
      lower(var.region) == "switzerlandnorth",
      lower(var.region) == "uksouth",
      lower(var.region) == "ukwest"
    ])
    error_message = "Please select one of the approved regions: northcentralus, southcentralus, westcentral, centralus, westus, eastus, northeurope, westeurope, norwayeast, norwaywest, swedencentral, switzerlandnorth, uksouth, or ukwest."
  }
}

variable "region_prefix_map" {
  type        = map(any)
  description = "A list of prefix strings to concat in locals. Can be replaced or appended."
  default = {
    northcentralus   = "ncu"
    southcentralus   = "scu"
    westcentral      = "wcu"
    centralus        = "usc"
    westus           = "usw"
    eastus           = "use"
    northeurope      = "eun"
    westeurope       = "euw"
    norwayeast       = "nwe"
    norwaywest       = "nwn"
    swedencentral    = "swc"
    switzerlandnorth = "sln"
    uksouth          = "uks"
    ukwest           = "ukw"
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

variable "st_container_name" {
  description = "Name of the storage container"
  type        = string
  default     = "default"
}

variable "retention_days" {
  description = "Retention days"
  type        = number
  default     = 0
}

variable "allowed_ips" {
  description = "Allowed external IPs"
  type        = list(string)
  default     = [""]
}
### End Storage Account Variables ###
variable "users" {
  description = "List of local SFTP user objects."
  type = list(object({
    name                 = string
    home_directory       = optional(string)
    ssh_key_enabled      = optional(bool, true)
    ssh_password_enabled = optional(bool, true)
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

### Automation Account Variables ### 

variable "automation_enabled" {
  description = "Enable automation account"
  type        = bool
  default     = false
}

# https://docs.microsoft.com/en-us/rest/api/maps/timezone/gettimezoneenumwindows
variable "region_timezone_map" {
  description = "Adds a timezone to chosen region, works just as the naming process."
  type        = map(any)
  default = {
    northcentralus   = "America/North_Dakota/Center"
    southcentralus   = "Atlantic/South_Georgia"
    westcentral      = "America/St_Thomas"
    centralus        = "America/Chicago"
    westus           = "America/St_Thomas"
    eastus           = "America/Cayenne"
    northeurope      = "Europe/Dublin"
    westeurope       = "Europe/Amsterdam"
    norwayeast       = "Europe/Oslo"
    norwaywest       = "Europe/Oslo"
    swedencentral    = "Europe/Oslo"
    switzerlandnorth = "Europe/Vienna"
    uksouth          = "Europe/london"
    ukwest           = "Europe/London"
  }
}

variable "sftp_enable_frequency" {
  description = "Enable frequency. Options are OneTime, Day, Hour, Week or Month"
  type        = string
  default     = "OneTime"
}

variable "interval" {
  description = "Reoccurance of schedule. Options are Day, Hour, Week or Month."
  type        = number
  default     = 1
}

variable "start_time" {
  description = "Start time, format YYYY-MM-DDTHH:MM:SS+02:00"
  type        = string
  default     = null
}

variable "expiry_time" {
  description = "Expiry time, format YYYY-MM-DDTHH:MM:SS+02:00"
  type        = string
  default     = null
}

variable "week_days" {
  description = "List of Week Days"
  type        = list(string)
  default     = null
}

variable "month_days" {
  description = "Month days from 1 to 31. -1 for the last day of month."
  type        = number
  default     = null
}

variable "monthly_occurence" {
  description = "Monthly occurence. Values from 1 to 5. -1 for the last week of the month."
  type        = string
  default     = null
}

variable "month_days_occurence" {
  description = "Month days occurence"
  type        = string
  default     = null
}

variable "region_timezone_map_locals" {
  description = "Adds a timezone to chosen region for locals timing, works just as the naming process."
  type        = map(any)
  default = {
    northcentralus   = "CT"
    southcentralus   = "GMT-7"
    westcentral      = "GMT-6"
    centralus        = "UTC-5"
    westus           = "PST"
    eastus           = "ET"
    northeurope      = "UTC"
    westeurope       = "GMT+1"
    norwayeast       = "UTC+1"
    norwaywest       = "UTC+1"
    swedencentral    = "UTC+1"
    switzerlandnorth = "UTC+1"
    uksouth          = "UTC"
    ukwest           = "UTC"
  }
}

variable "schedule_start" {
  description = "Start time, format HH:MM"
  type        = string
  default     = "00:00"
}

variable "schedule_stop" {
  description = "Stop time, format HH:MM"
  type        = string
  default     = "23:59"
}
#### End Automation Account Variables ###

### Start Backup Variables ###

variable "backup_enabled" {
  description = "Enable backup"
  type        = bool
  default     = false
}

variable "backup_redudancy" {
  description = "Backup redudancy"
  type        = string
  default     = "LocallyRedundant"
}