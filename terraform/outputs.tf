output "public_ips" {
  description = "Public IP of each VM (reachable only from allowed_ip)."
  value       = { for name, ip in azurerm_public_ip.vm : name => ip.ip_address }
}

output "private_ips" {
  description = "Static private IPs inside vnet-homelab."
  value       = { for name, cfg in local.vms : name => cfg.ip }
}

output "rdp_dc01" {
  description = "Connect to the domain controller."
  value       = "Remote desktop to ${azurerm_public_ip.vm["dc01"].ip_address} as ${var.domain_netbios_name}\\${var.admin_username}"
}

output "ssh_lnx01" {
  description = "SSH command for the Wazuh server."
  value       = var.deploy_lnx01 ? "ssh -i ${trimsuffix(var.ssh_public_key_path, ".pub")} ${var.admin_username}@${azurerm_public_ip.vm["lnx01"].ip_address}" : null
}

output "wazuh_dashboard" {
  description = "Wazuh dashboard URL (ready about 20 minutes after LNX01 boots)."
  value       = var.deploy_lnx01 ? "https://${azurerm_public_ip.vm["lnx01"].ip_address}" : null
}
