variable "subscription_id" {
  description = "Azure subscription ID (Azure for Students). Find it with: az account show --query id -o tsv"
  type        = string
}

variable "location" {
  description = "Azure region. The Azure for Students policy only allows a few regions; East US is blocked."
  type        = string
  default     = "northcentralus"
}

variable "resource_group_name" {
  description = "Resource group for the lab. Defaults to a separate group so a test build never touches the hand-built lab."
  type        = string
  default     = "rg-homelab-tf"
}

variable "allowed_ip" {
  description = "Your public IP address. RDP, SSH and the Wazuh dashboard are only reachable from here. Find it with: curl -s https://api.ipify.org"
  type        = string

  validation {
    condition     = can(cidrhost("${var.allowed_ip}/32", 0))
    error_message = "allowed_ip must be a single IPv4 address, for example 131.247.226.37."
  }
}

variable "admin_username" {
  description = "Admin user created on every VM (becomes the domain admin on DC01)."
  type        = string
  default     = "labadmin"
}

variable "admin_password" {
  description = "Password for the Windows admin account. 12+ characters, upper/lower case, number and symbol."
  type        = string
  sensitive   = true
}

variable "dsrm_password" {
  description = "Directory Services Restore Mode password for the domain controller."
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key for LNX01. Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/homelab_tf"
  type        = string
  default     = "~/.ssh/homelab_tf.pub"
}

variable "domain_name" {
  description = "Active Directory domain created on DC01."
  type        = string
  default     = "homelab.local"
}

variable "domain_netbios_name" {
  description = "NetBIOS name of the domain."
  type        = string
  default     = "HOMELAB"
}

variable "windows_vm_size" {
  description = "Size for DC01 and WS01."
  type        = string
  default     = "Standard_B2als_v2" # 2 vCPU, 4 GiB
}

variable "linux_vm_size" {
  description = "Size for LNX01. Wazuh needs 8 GiB of memory."
  type        = string
  default     = "Standard_B2as_v2" # 2 vCPU, 8 GiB
}

variable "deploy_ws01" {
  description = "Create the Windows 11 workstation and join it to the domain."
  type        = bool
  default     = true
}

variable "deploy_lnx01" {
  description = "Create the Ubuntu server and install Wazuh on first boot."
  type        = bool
  default     = true
}

variable "auto_shutdown_time" {
  description = "Daily auto-shutdown time (24-hour HHMM) for every VM."
  type        = string
  default     = "2300"
}

variable "auto_shutdown_timezone" {
  description = "Windows time zone name for auto-shutdown."
  type        = string
  default     = "Eastern Standard Time"
}

variable "budget_amount" {
  description = "Monthly budget in USD for the resource group."
  type        = number
  default     = 50
}

variable "budget_start_date" {
  description = "First day of the current month, RFC 3339 (budgets must start on the 1st)."
  type        = string
  default     = "2026-11-01T00:00:00Z"
}

variable "alert_email" {
  description = "Email for budget and auto-shutdown notifications."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    project    = "azure-homelab"
    managed_by = "terraform"
  }
}
