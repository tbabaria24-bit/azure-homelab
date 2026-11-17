# Phase 2 – Users, workstation, Group Policy and help desk

By the end of this phase the domain has departments, groups and 20 users; a Windows 11 workstation (WS01) is joined to it; Group Policy maps a company drive; and three common help desk tickets have been worked end to end.

> **Start order every session:** start DC01, wait about 3 minutes, then start WS01. The workstation needs the domain controller up to find the domain. If your public IP changed, update each VM's RDP rule (**Network settings → RDP → Source: My IP address**).

## 1. Build the directory (DC01)

In **Windows PowerShell (Admin)** on DC01:

```powershell
New-Item -ItemType Directory C:\Lab -Force; cd C:\Lab
iwr https://raw.githubusercontent.com/tbabaria24-bit/azure-homelab/main/scripts/phase2/New-LabUsers.ps1 -OutFile New-LabUsers.ps1
iwr https://raw.githubusercontent.com/tbabaria24-bit/azure-homelab/main/scripts/phase2/lab-users.csv -OutFile lab-users.csv
powershell -ExecutionPolicy Bypass -File .\New-LabUsers.ps1 -WhatIf   # dry run
powershell -ExecutionPolicy Bypass -File .\New-LabUsers.ps1           # for real; prompts for a temporary password
```

Open `dsa.msc` (Active Directory Users and Computers) to see **Lab → Users → IT / HR / Finance / Sales / Operations**.

## 2. Create WS01 and join the domain

| Setting | Value |
| --- | --- |
| Image | Windows 11 Pro (licensing box ticked) |
| Size | Standard_B2als_v2 |
| Subnet | `snet-workstations` (10.10.2.0/24) |
| Other | Standard SSD, auto-shutdown 11 PM, RDP locked to my IP |

Sign in as the local admin (`WS01\labadmin`), then in an elevated PowerShell:

```powershell
Resolve-DnsName homelab.local          # should return 10.10.1.4 (DC01)
Add-Computer -DomainName homelab.local -OUPath "OU=Workstations,OU=Computers,OU=Lab,DC=homelab,DC=local" -Credential HOMELAB\labadmin -Restart
```

After the restart, sign in as `HOMELAB\labadmin` and allow domain users to use Remote Desktop:

```powershell
Add-LocalGroupMember -Group "Remote Desktop Users" -Member "HOMELAB\Domain Users"
```

## 3. Password policy, file share and Group Policy (DC01)

```powershell
Set-ADDefaultDomainPasswordPolicy -Identity homelab.local -MinPasswordLength 12 -ComplexityEnabled $true -LockoutThreshold 5 -LockoutDuration 00:15:00 -LockoutObservationWindow 00:15:00
New-Item C:\Shares\Company -ItemType Directory -Force
New-SmbShare -Name Company -Path C:\Shares\Company -FullAccess "HOMELAB\Domain Admins" -ChangeAccess "HOMELAB\Domain Users"
icacls C:\Shares\Company /grant "HOMELAB\Domain Users:(OI)(CI)M"
```

Then in **Group Policy Management** (`gpmc.msc`):

1. **homelab.local → Lab → Users** → right-click → **Create a GPO in this domain, and Link it here** → `Lab - Mapped Drives`
2. Edit → **User Configuration → Preferences → Windows Settings → Drive Maps → New → Mapped Drive**
3. Action **Create**, location `\\DC01\Company`, **Reconnect**, label `Company`, drive letter **S**

On WS01, run `gpupdate /force`, sign out and back in, and **Company (S:)** appears in This PC.

## 4. Help desk tickets

**Password reset (Maya Patel)**

```powershell
Set-ADAccountPassword maya.patel -Reset -NewPassword (Read-Host "New password" -AsSecureString)
Set-ADUser maya.patel -ChangePasswordAtLogon $false
```

Remote Desktop uses Network Level Authentication, which can't complete a sign-in for an account that must change its password first. That's why the reset also clears the flag.

**Account lockout (Nina Lopez).** Cause it with 6 wrong passwords over RDP, then:

```powershell
Search-ADAccount -LockedOut | Select-Object Name, SamAccountName
Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 3 | Format-List TimeCreated, Message
Unlock-ADAccount nina.lopez
```

**Offboarding (Tyler Ward)**

```powershell
$u = "tyler.ward"
Disable-ADAccount $u
Set-ADUser $u -Description "Offboarded 2026-11-17 - left company (ticket HD-1001)"
Get-ADPrincipalGroupMembership $u | Where-Object Name -ne "Domain Users" | ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $u -Confirm:$false }
Move-ADObject (Get-ADUser $u).DistinguishedName -TargetPath "OU=Disabled Users,OU=Lab,DC=homelab,DC=local"
```

## End of session

Stop **WS01**, then **DC01**, and wait for **Stopped (deallocated)** on both.
