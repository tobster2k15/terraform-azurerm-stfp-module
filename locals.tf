# #Namingconvention: Counter wird bei den einzelnen Namen mit angegeben
locals {
  rg_name     = "rg-${var.business_unit}-${var.usecase}-${var.environment}-001"
  rg_name_shd = "rg-${var.business_unit}-${var.usecase}-shd-001"

  nic_name     = "nic-${var.usecase}-${var.environment}-"
  rg_vnet_name = "rg-vnet-${var.usecase}-${var.environment}-${var.region_prefix_map[var.region]}-001"
  vnet_name    = "vnet-${var.usecase}-${var.environment}-${var.region}-001"

  snet_name_shd            = "snet-${var.usecase}-shd-001"
  nsg_name                 = "nsg-${var.usecase}-${var.environment}-${var.region}-001"
  pep_name                 = "pep-${var.usecase}-shd-${var.region}-001"
  psc_name                 = "psc-${var.usecase}-${var.environment}-${var.region}-001"
  rt_name                  = "rt-${var.usecase}-default"
  st_name                  = "st${var.usecase}sftp${var.environment}001"
  automation_name          = "aa-${var.usecase}-${var.environment}-001"
  automation_schedule_name = "as-${var.usecase}-${var.environment}"
  bvault_name              = "bvault-${var.usecase}-${var.environment}-001"
  bkpol_name               = "bkpol-${var.usecase}-${var.environment}-001"
}

locals {
  #Standard Tags, forced by policy: OPE, Cost Center & Responsible Team
  #tags get inherited by another policy, but if they're not set individually, they'll get deleted after making changes
  users = {
    for user in var.users : user.name => user
  }

  sftp_users_with_ssh_key_enabled = {
    for key, value in local.users : key => value if value.ssh_key_enabled
  }

  users_permissions = [
    "All",
    "Read",
    "Write",
    "List",
    "Delete",
    "Create",
  ]

  users_output = {
    for key, value in azurerm_storage_account_local_user.users : key => {
      id       = value.id
      name     = value.name
      password = value.password

      auto_generated_private_key = try(tls_private_key.users_keys[key].private_key_pem, "")
      auto_generated_public_key  = try(tls_private_key.users_keys[key].public_key_openssh, "")
    }
  }
}

locals {
  update_time_start = var.schedule_start
  update_date       = substr(time_offset.tomorrow.rfc3339, 0, 10)
  update_timezone   = var.region_timezone_map_locals[var.region]
  update_time_stop  = var.schedule_stop
}