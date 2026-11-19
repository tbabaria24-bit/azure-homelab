# ---------------------------------------------------------------------------
# DC01 – Windows Server 2022 domain controller
# ---------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "dc01" {
  name                  = "DC01"
  computer_name         = "DC01"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.windows_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm["dc01"].id]
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {} # managed storage; lets you see the console from the portal
}

resource "azurerm_virtual_machine_extension" "promote_dc" {
  name                 = "promote-dc"
  virtual_machine_id   = azurerm_windows_virtual_machine.dc01.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = var.tags

  # protected_settings are encrypted, so the DSRM password never appears in the portal.
  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(templatefile("${path.module}/templates/promote-dc.ps1.tftpl", {
      domain_name   = var.domain_name
      netbios_name  = var.domain_netbios_name
      dsrm_password = replace(var.dsrm_password, "'", "''")
    }), "UTF-16LE")}"
  })
}

# The promotion reboots DC01 and Active Directory needs a few minutes to start.
resource "time_sleep" "wait_for_domain" {
  count           = var.deploy_ws01 ? 1 : 0
  depends_on      = [azurerm_virtual_machine_extension.promote_dc]
  create_duration = "12m"
}

# ---------------------------------------------------------------------------
# WS01 – Windows 11 workstation, joined to the domain
# ---------------------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "ws01" {
  count                 = var.deploy_ws01 ? 1 : 0
  name                  = "WS01"
  computer_name         = "WS01"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  size                  = var.windows_vm_size
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.vm["ws01"].id]
  license_type          = "Windows_Client" # Windows 11 licensing benefit
  tags                  = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-pro"
    version   = "latest"
  }

  boot_diagnostics {}
}

resource "azurerm_virtual_machine_extension" "join_domain" {
  count                = var.deploy_ws01 ? 1 : 0
  name                 = "join-domain"
  virtual_machine_id   = azurerm_windows_virtual_machine.ws01[0].id
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on           = [time_sleep.wait_for_domain]
  tags                 = var.tags

  settings = jsonencode({
    Name    = var.domain_name
    User    = "${var.domain_netbios_name}\\${var.admin_username}"
    Restart = "true"
    Options = "3" # join the domain and create the computer account
  })

  protected_settings = jsonencode({
    Password = var.admin_password
  })
}

# ---------------------------------------------------------------------------
# LNX01 – Ubuntu 24.04 running the Wazuh SIEM
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "lnx01" {
  count                           = var.deploy_lnx01 ? 1 : 0
  name                            = "LNX01"
  computer_name                   = "LNX01"
  location                        = azurerm_resource_group.lab.location
  resource_group_name             = azurerm_resource_group.lab.name
  size                            = var.linux_vm_size
  admin_username                  = var.admin_username
  disable_password_authentication = true # SSH keys only
  network_interface_ids           = [azurerm_network_interface.vm["lnx01"].id]
  tags                            = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(pathexpand(var.ssh_public_key_path))
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/templates/lnx01-cloud-init.yaml.tftpl", {
    wazuh_version = "4.14"
  }))

  boot_diagnostics {}
}

# ---------------------------------------------------------------------------
# Auto-shutdown for every VM
# ---------------------------------------------------------------------------
locals {
  vm_ids = merge(
    { dc01 = azurerm_windows_virtual_machine.dc01.id },
    var.deploy_ws01 ? { ws01 = azurerm_windows_virtual_machine.ws01[0].id } : {},
    var.deploy_lnx01 ? { lnx01 = azurerm_linux_virtual_machine.lnx01[0].id } : {},
  )
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  for_each              = local.vm_ids
  virtual_machine_id    = each.value
  location              = azurerm_resource_group.lab.location
  enabled               = true
  daily_recurrence_time = var.auto_shutdown_time
  timezone              = var.auto_shutdown_timezone
  tags                  = var.tags

  notification_settings {
    enabled         = true
    email           = var.alert_email
    time_in_minutes = 30
  }
}
