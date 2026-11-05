<#
.SYNOPSIS
    Promotes a fresh Windows Server to the first domain controller of a new forest.

.DESCRIPTION
    Phase 1 of the Azure homelab. Run in an elevated PowerShell session on DC01.
    You will be prompted for the Directory Services Restore Mode (DSRM) password;
    it is never stored in this script. The server restarts automatically when done.

.EXAMPLE
    .\Install-DomainController.ps1
    .\Install-DomainController.ps1 -DomainName "corp.example.local" -NetbiosName "CORP"
#>
[CmdletBinding()]
param(
    [string]$DomainName  = "homelab.local",
    [string]$NetbiosName = "HOMELAB"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing the AD DS role and management tools..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools | Format-Table Success, RestartNeeded, ExitCode

Write-Host "Creating forest '$DomainName' with integrated DNS. You'll be asked for the DSRM password." -ForegroundColor Cyan
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName -InstallDns

# After the automatic restart, sign in as $NetbiosName\<admin> and run:
#   Add-DnsServerForwarder -IPAddress 168.63.129.16   # Azure's DNS resolver
#   Get-ADDomain | Format-List DNSRoot, NetBIOSName
#   Resolve-DnsName microsoft.com
