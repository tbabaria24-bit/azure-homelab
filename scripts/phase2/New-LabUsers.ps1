<#
.SYNOPSIS
    Builds the homelab's Active Directory structure: OUs, department groups and users.

.DESCRIPTION
    Phase 2 of the Azure homelab. Run on DC01 in an elevated PowerShell session.
      - OUs:    Lab > Users > <Department>, Lab > Computers > Workstations / Servers,
                Lab > Groups, Lab > Disabled Users
      - Groups: one global security group per department (GG-<Department>),
                plus GG-Helpdesk for help desk staff
      - Users:  read from lab-users.csv (fictional people); sAMAccountName = first.last

    You are prompted once for a temporary password. Every user must change it at
    first sign-in. The password is never written to disk or to the log.
    Safe to re-run: anything that already exists is skipped. Supports -WhatIf.

.EXAMPLE
    .\New-LabUsers.ps1 -WhatIf      # dry run, shows what would be created
    .\New-LabUsers.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath,
    [string]$LogPath
)

$ErrorActionPreference = "Stop"

# Windows PowerShell 5.1 leaves $PSScriptRoot empty inside param defaults, so resolve here.
$here = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
if (-not $CsvPath) { $CsvPath = Join-Path $here "lab-users.csv" }
if (-not $LogPath) { $LogPath = Join-Path $here "New-LabUsers.log" }
Import-Module ActiveDirectory

$domain = Get-ADDomain
$root   = $domain.DistinguishedName          # DC=homelab,DC=local
$upn    = $domain.DNSRoot                    # homelab.local

function Write-Log([string]$Message, [string]$Color = "Gray") {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line -ForegroundColor $Color
    if (-not $WhatIfPreference) { Add-Content -Path $LogPath -Value $line }
}

function Ensure-OU([string]$Name, [string]$Path) {
    $dn = "OU=$Name,$Path"
    if (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue) {
        Write-Log "OU exists:      $dn"
    } elseif ($PSCmdlet.ShouldProcess($dn, "Create OU")) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Log "Created OU:     $dn" Green
    }
    return $dn
}

function Ensure-Group([string]$Name, [string]$Path, [string]$Description) {
    if (Get-ADGroup -Filter "Name -eq '$Name'" -ErrorAction SilentlyContinue) {
        Write-Log "Group exists:   $Name"
    } elseif ($PSCmdlet.ShouldProcess($Name, "Create group")) {
        New-ADGroup -Name $Name -Path $Path -GroupScope Global -GroupCategory Security -Description $Description
        Write-Log "Created group:  $Name" Green
    }
}

if (-not (Test-Path $CsvPath)) { throw "User list not found: $CsvPath" }
$people = Import-Csv $CsvPath
$departments = $people.Department | Sort-Object -Unique

# --- OU structure -----------------------------------------------------------
$labOU      = Ensure-OU "Lab" $root
$usersOU    = Ensure-OU "Users" $labOU
$computerOU = Ensure-OU "Computers" $labOU
$null       = Ensure-OU "Workstations" $computerOU
$null       = Ensure-OU "Servers" $computerOU
$groupsOU   = Ensure-OU "Groups" $labOU
$null       = Ensure-OU "Disabled Users" $labOU
foreach ($dept in $departments) { $null = Ensure-OU $dept $usersOU }

# --- Groups -----------------------------------------------------------------
foreach ($dept in $departments) { Ensure-Group "GG-$dept" $groupsOU "All $dept department staff" }
Ensure-Group "GG-Helpdesk" $groupsOU "Help desk staff: password resets and account unlocks"

# --- Users ------------------------------------------------------------------
$password = $null
if (-not $WhatIfPreference) {
    $password = Read-Host "Temporary password for all new users (they must change it at first sign-in)" -AsSecureString
}

$created = 0
foreach ($p in $people) {
    $sam = ("{0}.{1}" -f $p.FirstName, $p.LastName).ToLower()
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        Write-Log "User exists:    $sam"
        continue
    }
    $ou = "OU=$($p.Department),$usersOU"
    if ($PSCmdlet.ShouldProcess("$sam ($($p.Title), $($p.Department))", "Create user")) {
        New-ADUser -Name "$($p.FirstName) $($p.LastName)" `
            -GivenName $p.FirstName -Surname $p.LastName `
            -SamAccountName $sam -UserPrincipalName "$sam@$upn" `
            -DisplayName "$($p.FirstName) $($p.LastName)" `
            -Title $p.Title -Department $p.Department -Company "Homelab Corp" `
            -Path $ou -AccountPassword $password `
            -ChangePasswordAtLogon $true -Enabled $true
        Add-ADGroupMember -Identity "GG-$($p.Department)" -Members $sam
        if ($p.Title -like "*Help Desk*") { Add-ADGroupMember -Identity "GG-Helpdesk" -Members $sam }
        Write-Log "Created user:   $sam  ->  $($p.Department)" Green
        $created++
    }
}

Write-Log "Done. $created new users created." Cyan
