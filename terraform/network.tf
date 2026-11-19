resource "azurerm_resource_group" "lab" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-homelab"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.10.0.0/16"]

  # DC01 is the primary DNS server so every VM can find the domain. Azure DNS is a
  # fallback, which keeps internet lookups working while DC01 is still being promoted.
  dns_servers = [local.ip.dc01, "168.63.129.16"]

  tags = var.tags
}

resource "azurerm_subnet" "servers" {
  name                 = "snet-servers"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "workstations" {
  name                 = "snet-workstations"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.2.0/24"]
}

# One network security group per VM, each allowing only the management ports it
# needs, and only from allowed_ip. Traffic between VMs uses the built-in
# AllowVnetInBound rule (domain traffic, Wazuh agents on 1514/1515).
locals {
  ip = {
    dc01  = "10.10.1.4"
    lnx01 = "10.10.1.5"
    ws01  = "10.10.2.4"
  }

  all_vms = {
    dc01  = { subnet_id = azurerm_subnet.servers.id, ip = local.ip.dc01, ports = [{ name = "RDP", port = 3389 }] }
    ws01  = { subnet_id = azurerm_subnet.workstations.id, ip = local.ip.ws01, ports = [{ name = "RDP", port = 3389 }] }
    lnx01 = { subnet_id = azurerm_subnet.servers.id, ip = local.ip.lnx01, ports = [{ name = "SSH", port = 22 }, { name = "Wazuh-Dashboard", port = 443 }] }
  }

  enabled_vms = concat(["dc01"], var.deploy_ws01 ? ["ws01"] : [], var.deploy_lnx01 ? ["lnx01"] : [])
  vms         = { for name, cfg in local.all_vms : name => cfg if contains(local.enabled_vms, name) }

  nsg_rules = merge([
    for vm, cfg in local.vms : {
      for i, rule in cfg.ports : "${vm}-${rule.name}" => {
        vm       = vm
        name     = rule.name
        port     = rule.port
        priority = 300 + i * 10
      }
    }
  ]...)
}

resource "azurerm_network_security_group" "vm" {
  for_each            = local.vms
  name                = "${upper(each.key)}-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "mgmt" {
  for_each                    = local.nsg_rules
  name                        = each.value.name
  priority                    = each.value.priority
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(each.value.port)
  source_address_prefix       = "${var.allowed_ip}/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.lab.name
  network_security_group_name = azurerm_network_security_group.vm[each.value.vm].name
}

resource "azurerm_public_ip" "vm" {
  for_each            = local.vms
  name                = "${upper(each.key)}-ip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "vm" {
  for_each            = local.vms
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = each.value.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.ip
    public_ip_address_id          = azurerm_public_ip.vm[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  for_each                  = local.vms
  network_interface_id      = azurerm_network_interface.vm[each.key].id
  network_security_group_id = azurerm_network_security_group.vm[each.key].id
}
