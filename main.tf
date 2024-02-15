resource "azurerm_resource_group" "rg_vnet_hub" {
  name     = var.rg_hub_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub-${azurerm_resource_group.rg_vnet_hub.location}"
  location            = azurerm_resource_group.rg_vnet_hub.location
  resource_group_name = azurerm_resource_group.rg_vnet_hub.name
  address_space       = var.vnet_hub_address
}

resource "azurerm_subnet" "sub_fw_hub" {
  count = var.enable_firewall == true ? 1 : 0

  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg_vnet_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = var.subnet_address_firewall
}

resource "azurerm_public_ip" "pip_fw_hub" {
  count = var.enable_firewall == true ? 1 : 0

  name                = "pip-fw-${azurerm_resource_group.rg_vnet_hub.location}"
  location            = azurerm_resource_group.rg_vnet_hub.location
  resource_group_name = azurerm_resource_group.rg_vnet_hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "fw_hub" {
  count = var.enable_firewall == true ? 1 : 0

  name                = "fw-${azurerm_resource_group.rg_vnet_hub.location}"
  location            = azurerm_resource_group.rg_vnet_hub.location
  resource_group_name = azurerm_resource_group.rg_vnet_hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.fw_policy[0].id

  ip_configuration {
    name                 = "config-pip-fw"
    subnet_id            = azurerm_subnet.sub_fw_hub[0].id
    public_ip_address_id = azurerm_public_ip.pip_fw_hub[0].id
  }
}

resource "azurerm_firewall_policy" "fw_policy" {
  count = var.enable_firewall == true ? 1 : 0

  name                = "fw-policy-${azurerm_resource_group.rg_vnet_hub.location}"
  resource_group_name = azurerm_resource_group.rg_vnet_hub.name
  location            = azurerm_resource_group.rg_vnet_hub.location
  sku                 = "Standard"

  dns {
    proxy_enabled = false
    servers       = []
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "fw_policy_collection_group" {
  for_each = var.enable_firewall == true ? var.policy_rule_collection : {}

  name               = each.key
  firewall_policy_id = azurerm_firewall_policy.fw_policy[0].id
  priority           = each.value.priority

  dynamic "application_rule_collection" {
    for_each = each.value.application_rule_collection == {} ? {} : each.value.application_rule_collection
    iterator = application
    content {
      name     = application.value.name
      priority = application.value.priority
      action   = application.value.action
      dynamic "rule" {
        for_each = application.value.rule == {} ? {} : application.value.rule
        iterator = rules
        content {
          name = rules.value.name
          dynamic "protocols" {
            for_each = rules.value.protocols == {} ? {} : rules.value.protocols
            iterator = protocol
            content {
              type = protocol.value.type
              port = protocol.value.port
            }
          }
          source_addresses  = rules.value.source_addresses
          destination_fqdns = rules.value.destination_fqdns
        }
      }
    }
  }

  dynamic "network_rule_collection" {
    for_each = each.value.network_rule_collection == null ? {} : each.value.network_rule_collection
    iterator = network
    content {
      name     = network.value.name
      priority = network.value.priority
      action   = network.value.action
      dynamic "rule" {
        for_each = network.value.rule == null ? {} : network.value.rule
        iterator = rules
        content {
          name                  = rules.value.name
          protocols             = rules.value.protocols
          source_addresses      = rules.value.source_addresses
          destination_addresses = rules.value.destination_address
          destination_ports     = rules.value.destination_ports
        }
      }
    }
  }

  dynamic "nat_rule_collection" {
    for_each = each.value.nat_rule_collection == null ? {} : each.value.nat_rule_collection
    iterator = nat
    content {
      name     = nat.value.name
      priority = nat.value.priority
      action   = nat.value.action
      dynamic "rule" {
        for_each = nat.value.rule == null ? {} : nat.value.rule
        iterator = rules
        content {
          name                = rules.value.name
          protocols           = rules.value.protocols
          source_addresses    = rules.value.source_addresses
          destination_address = rules.value.destination_address
          destination_ports   = rules.value.destination_ports
          translated_address  = rules.value.translated_address
          translated_port     = rules.value.translated_port
        }
      }
    }
  }

  depends_on = [azurerm_firewall_policy.fw_policy]
}
