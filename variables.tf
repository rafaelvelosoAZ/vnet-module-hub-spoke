variable "rg_hub_name" {
  type    = string
  default = "rg-vnet-hub-eastus"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "enable_firewall" {
  type    = bool
  default = true
}

variable "vnet_hub_address" {
  type    = list(any)
  default = ["10.1.0.0/16"]
}

variable "subnet_address_firewall" {
  type    = list(any)
  default = ["10.1.0.0/24"]
}

variable "policy_rule_collection" {
  type    = any
  default = {
    policy-collection-group = {
        priority = 100
        application_rule_collection = {}
        network_rule_collection = {}
        nat_rule_collection = {}
    }
  }
}