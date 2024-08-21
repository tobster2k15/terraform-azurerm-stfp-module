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
  depends_on = [azurerm_storage_container.mycontainer]
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

resource "azurerm_storage_account_local_user" "local_user" {
  for_each             = local.users
  name                 = each.key
  storage_account_id   = azurerm_storage_account.storage.id
  ssh_key_enabled      = each.value.ssh_key_enabled
  ssh_password_enabled = each.value.ssh_password_enabled
  home_directory       = coalesce(each.value.mycontainer, each.value.permissions_scopes[0].target_container)
  depends_on           = [azurerm_storage_account.storage, azurerm_storage_container.mycontainer]
  dynamic "permission_scope" {
    for_each = each.value.permissions_scopes
    content {
      service       = "blob"
      resource_name = permission_scope.value.target_container
      permissions = {
        create = contains(permission_scope.value.permissions_scopes, "Create") || contains(permission_scope.value.permissions_scopes, "All")
        delete = contains(permission_scope.value.permissions_scopes, "Delete") || contains(permission_scope.value.permissions_scopes, "All")
        list   = contains(permission_scope.value.permissions_scopes, "List")   || contains(permission_scope.value.permissions_scopes, "All")
        read   = contains(permission_scope.value.permissions_scopes, "Read")   || contains(permission_scope.value.permissions_scopes, "All")
        write  = contains(permission_scope.value.permissions_scopes, "Write")  || contains(permission_scope.value.permissions_scopes, "All")
      }
    }
  }
}

# resource "azurerm_storage_account_local_user" "local_user" {
#   name                 = "user1"
#   storage_account_id   = azurerm_storage_account.storage.id
#   ssh_key_enabled      = false
#   ssh_password_enabled = true
#   home_directory       = azurerm_storage_container.mycontainer.name
#   depends_on           = [azurerm_storage_account.storage, azurerm_storage_container.mycontainer]
#   permission_scope {
#     permissions {
#       read   = true
#       create = true
#     }
#     service       = "blob"
#     resource_name = azurerm_storage_container.mycontainer.name
#   }
# }