# Phase 1 – Domain controller

By the end of this phase, DC01 runs Active Directory and DNS for `homelab.local` in a private Azure network that only your IP can reach.

## Lab plan

| Setting | Value |
| --- | --- |
| Subscription | Azure for Students |
| Region | North Central US (the student policy blocks East US) |
| Resource group | `rg-homelab` |
| Virtual network | `vnet-homelab` · `10.10.0.0/16` |
| Server subnet | `snet-servers` · `10.10.1.0/24` |
| Workstation subnet | `snet-workstations` · `10.10.2.0/24` |
| Domain controller | `DC01` · Standard_B2als_v2 · static IP `10.10.1.4` |
| Domain | `homelab.local` · NetBIOS `HOMELAB` |
| Admin user | `labadmin` (password kept in a password manager, never in this repo) |

## 1. Cost guardrails

1. **Subscriptions → Azure for Students → Budgets → + Add**: `homelab-budget`, monthly, $50, alerts at 50% and 90% (actual).
2. Every VM gets **auto-shutdown** at 11 PM Eastern (set during VM creation, Management tab).

## 2. Network

1. **Resource groups → + Create**: `rg-homelab`.
2. **Virtual networks → + Create**: `vnet-homelab` in North Central US. Leave Bastion, Firewall and DDoS off (they bill hourly). Address space `10.10.0.0/16`; delete the default subnet; add `snet-servers` (`10.10.1.0/24`) and `snet-workstations` (`10.10.2.0/24`).

## 3. DC01 virtual machine

| Tab | Setting |
| --- | --- |
| Basics | `DC01`, North Central US, no redundancy, Security type Standard, Windows Server 2022 Datacenter x64 Gen2, Standard_B2als_v2, user `labadmin`, RDP (3389) allowed |
| Disks | Standard SSD |
| Networking | `vnet-homelab` / `snet-servers`, new public IP, Basic NSG, delete public IP and NIC with the VM |
| Management | Auto-shutdown 11:00 PM Eastern, email notification |

## 4. Static IP and RDP lockdown

1. **DC01 → Network settings → (network interface) → IP configurations → ipconfig1**: allocation **Static**, `10.10.1.4`. A domain controller's address must never change.
2. **DC01 → Network settings → RDP rule**: Source **My IP address**. Repeat this whenever your public IP changes (for example, switching between campus and home Wi-Fi).

## 5. Promote to domain controller

Connect with Windows App (Mac) or Remote Desktop, open **Windows PowerShell (Admin)**, and run [`scripts/phase1/Install-DomainController.ps1`](../scripts/phase1/Install-DomainController.ps1), or the two commands inside it. Enter a Directory Services Restore Mode password when prompted. DC01 restarts by itself; sign back in as `HOMELAB\labadmin`.

```powershell
Add-DnsServerForwarder -IPAddress 168.63.129.16
Get-ADDomain | Format-List DNSRoot, NetBIOSName
Resolve-DnsName microsoft.com
```

## 6. Point the network at DC01

**vnet-homelab → DNS servers → Custom → `10.10.1.4` → Save**, then restart DC01. Every VM added later uses DC01 for DNS and can find the domain.

## End of every session

Stop DC01 in the portal and wait for **Stopped (deallocated)**. Compute billing stops only in that state.
