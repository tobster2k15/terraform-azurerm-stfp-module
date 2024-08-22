resource "azurerm_resource_group" "myrg_shd" {
  name     = local.rg_name
  location = var.region
  tags     = var.tags
}

resource "azurerm_resource_group" "myrg_vnet" {
  count    = var.private_endpoint_enabled ? 1 : 0
  name     = local.rg_vnet_name
  location = var.region
  tags     = var.tags
}

resource "azurerm_virtual_network" "myvnet" {
  count               = var.private_endpoint_enabled == true ? 1 : 0
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.myrg_vnet[count.index].name
  location            = azurerm_resource_group.myrg_vnet[count.index].location
  address_space       = var.address_space
}

resource "azurerm_subnet" "mysubnet" {
  count                = var.private_endpoint_enabled == true ? 1 : 0
  name                 = local.snet_name_shd
  resource_group_name  = azurerm_resource_group.myrg_vnet[count.index].name
  virtual_network_name = azurerm_virtual_network.myvnet[count.index].name
  address_prefixes     = var.address_prefix
}

resource "azurerm_private_dns_zone" "dnszone_st" {
  count               = var.private_endpoint_enabled == true ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.myrg_vnet[count.index].name
  tags                = var.tags
}

resource "azurerm_private_dns_a_record" "dnszone_st" {
  count               = var.private_endpoint_enabled == true ? 1 : 0
  name                = "${local.st_name}.blob.core.windows.net"
  zone_name           = azurerm_private_dns_zone.dnszone_st[count.index].name
  resource_group_name = azurerm_resource_group.myrg_vnet[count.index].name
  ttl                 = 300
  records             = [azurerm_private_endpoint.endpoint_st[count.index].private_service_connection.0.private_ip_address]
  tags                = var.tags
}

resource "azurerm_private_endpoint" "endpoint_st" {
  count               = var.private_endpoint_enabled == true ? 1 : 0
  name                = "${local.pep_name}-st"
  location            = azurerm_resource_group.myrg_vnet[count.index].location
  resource_group_name = azurerm_resource_group.myrg_vnet[count.index].name
  subnet_id           = azurerm_subnet.mysubnet[count.index].id
  tags                = var.tags

  private_service_connection {
    name                           = local.psc_name
    private_connection_resource_id = azurerm_storage_account.storage.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
  private_dns_zone_group {
    name                 = "dns-blob-${var.business_unit}"
    private_dns_zone_ids = azurerm_private_dns_zone.dnszone_st[count.index].*.id
  }
}

# Deny Traffic from Public Networks with white list exceptions
resource "azurerm_storage_account_network_rules" "stfw" {
  storage_account_id = azurerm_storage_account.storage.id
  default_action     = "Deny"
  bypass             = ["AzureServices"]
  depends_on         = [azurerm_storage_container.mycontainer]
}

resource "azurerm_storage_account" "storage" {
  name                             = local.st_name #"${lower(random_string.random.result)}-st"
  resource_group_name              = azurerm_resource_group.myrg_shd.name
  location                         = azurerm_resource_group.myrg_shd.location
  min_tls_version                  = "TLS1_2"
  account_kind                     = var.st_account_kind
  account_tier                     = var.st_account_tier
  account_replication_type         = var.st_replication
  public_network_access_enabled    = true #Needs to be changed later on (portal), otherwise share can't be created
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  enable_https_traffic_only        = true
  large_file_share_enabled         = false
  is_hns_enabled                   = true
  sftp_enabled                     = true
  tags                             = var.tags
  identity {
    type = "SystemAssigned"
  }
  ## lifecylce block needed for if your storage account already is domain joined ##
  lifecycle {
    ignore_changes = [azure_files_authentication]
  }
}

resource "azurerm_storage_container" "mycontainer" {
  name                  = var.st_container_name
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.storage.name
  depends_on            = [azurerm_storage_account.storage]
}

resource "azurerm_private_dns_zone_virtual_network_link" "filelink" {
  count                 = var.private_endpoint_enabled == true ? 1 : 0
  name                  = "azbloblink-${var.business_unit}"
  resource_group_name   = azurerm_resource_group.myrg_vnet[count.index].name
  private_dns_zone_name = azurerm_private_dns_zone.dnszone_st[count.index].name
  virtual_network_id    = azurerm_virtual_network.myvnet[count.index].id

  lifecycle { ignore_changes = [tags] }
}

resource "azurerm_storage_account_local_user" "users" {
  for_each = local.users

  name = each.key

  storage_account_id = azurerm_storage_account.storage.id

  ssh_key_enabled      = each.value.ssh_key_enabled
  ssh_password_enabled = each.value.ssh_password_enabled

  # The first container in the `permissions_scopes` list will always be the default home directory
  home_directory = coalesce(each.value.home_directory, each.value.permissions_scopes[0].target_container)

  # https://learn.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-support#container-permissions
  dynamic "permission_scope" {
    for_each = each.value.permissions_scopes
    content {
      service       = "blob"
      resource_name = permission_scope.value.target_container
      permissions {
        create = contains(permission_scope.value.permissions, "All") || contains(permission_scope.value.permissions, "Create")
        delete = contains(permission_scope.value.permissions, "All") || contains(permission_scope.value.permissions, "Delete")
        list   = contains(permission_scope.value.permissions, "All") || contains(permission_scope.value.permissions, "List")
        read   = contains(permission_scope.value.permissions, "All") || contains(permission_scope.value.permissions, "Read")
        write  = contains(permission_scope.value.permissions, "All") || contains(permission_scope.value.permissions, "Write")
      }
    }
  }

  dynamic "ssh_authorized_key" {
    for_each = each.value.ssh_key_enabled ? ["auto"] : []
    content {
      key         = tls_private_key.users_keys[each.key].public_key_openssh
      description = "Automatically generated by Terraform"
    }
  }

  dynamic "ssh_authorized_key" {
    for_each = each.value.ssh_key_enabled ? each.value.ssh_authorized_keys : []
    content {
      key         = ssh_authorized_key.value.key
      description = ssh_authorized_key.value.description
    }
  }
}

resource "tls_private_key" "users_keys" {
  for_each = local.sftp_users_with_ssh_key_enabled

  algorithm = "RSA"
  rsa_bits  = 4096
}

### Optional ### 
resource "azurerm_automation_account" "automation" {
  count               = var.automation_enabled == true ? 1 : 0
  location            = azurerm_resource_group.myrg_shd.location
  name                = local.automation_name
  resource_group_name = azurerm_resource_group.myrg_shd.name
  sku_name            = "Basic"
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_automation_runbook" "sftp_enable" {
  count                   = var.automation_enabled == true ? 1 : 0
  automation_account_name = azurerm_automation_account.automation[count.index].name
  content                 = "Connect-AzAccount\r\n\r\n$resourceGroup = \"{azurerm_resource_group.myrg_shd.name}\"\r\n$storageAccount = \"{azurerm_storage_account.storage.name}\"\r\n\r\naz storage account update -g $resourceGroup -n $storageAccount --enable-sftp true"
  location                = azurerm_resource_group.myrg_shd.location
  log_progress            = false
  log_verbose             = false
  name                    = "sftp_enable"
  resource_group_name     = azurerm_resource_group.myrg_shd.name
  runbook_type            = "PowerShell72"
  depends_on = [
    azurerm_automation_account.automation,
  ]
}

resource "azurerm_automation_runbook" "sftp_disable" {
  count                   = var.automation_enabled == true ? 1 : 0
  automation_account_name = azurerm_automation_account.automation[count.index].name
  content                 = "Connect-AzAccount\r\n\r\n$resourceGroup = \"{azurerm_resource_group.myrg_shd.name}\"\r\n$storageAccount = \"{azurerm_storage_account.storage.name}\"\r\n\r\naz storage account update -g $resourceGroup -n $storageAccount --enable-sftp false"
  location                = azurerm_resource_group.myrg_shd.location
  log_progress            = false
  log_verbose             = false
  name                    = "sftp_disable"
  resource_group_name     = azurerm_resource_group.myrg_shd.name
  runbook_type            = "PowerShell72"
  depends_on = [
    azurerm_automation_account.automation,
  ]
}

resource "azurerm_automation_schedule" "sftp_enable" {
  count                   = var.automation_enabled == true ? 1 : 0
  name                    = "${local.automation_schedule_name}-on"
  resource_group_name     = azurerm_resource_group.myrg_shd.name
  automation_account_name = azurerm_automation_account.automation[count.index].name
  frequency               = var.sftp_enable_frequency
  interval                = var.interval
  timezone                = var.region_timezone_map[var.region]
  start_time              = var.start_time == null ? local.current_time : null
  expiry_time             = var.expiry_time != null ? var.expiry_time : null
  description             = "Start of SFTP Cycle"
  week_days               = var.week_days != null ? var.week_days : null
  month_days              = var.month_days != null ? var.month_days : null
  dynamic "monthly_occurence" {
    count = var.month_days != null ? var.monthly_occurence : null
    content {
      occurence = var.monthly_occurence
      day       = var.month_days_occurence
    }
  }

}

resource "azurerm_automation_schedule" "sftp_disable" {
  count                   = var.automation_enabled == true ? 1 : 0
  name                    = "${local.automation_schedule_name}-off"
  resource_group_name     = azurerm_resource_group.myrg_shd[count.index].name
  automation_account_name = azurerm_automation_account.sftp_enable[count.index].name
  frequency               = var.sftp_enable_frequency
  interval                = var.interval
  timezone                = var.region_timezone_map[var.region]
  start_time              = var.start_time == null ? local.current_time : null
  expiry_time             = var.expiry_time != null ? var.expiry_time : null
  description             = "End of SFTP Cycle"
  week_days               = var.week_days != null ? var.week_days : null
  month_days              = var.month_days != null ? var.month_days : null
  dynamic "monthly_occurence" {
    count = var.month_days != null ? var.monthly_occurence : null
    content {
      occurence = var.monthly_occurence
      day       = var.month_days_occurence
    }
  }
}