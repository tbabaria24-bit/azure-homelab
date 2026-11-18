# Build log

Real problems I ran into while building the lab, and how I solved them.

## 2026-11-05 · Phase 1

### Virtual network deployment failed with "policy violation"

- **Symptom:** creating `vnet-homelab` in East US failed. The portal's error panel was empty.
- **Investigation:** the resource group's **Activity log** showed `Validate Deployment` failing with `InvalidTemplateDeployment: ... failed because of policy violation`. Under **Policy → Assignments** I found a system policy on the subscription, **Allowed resource deployment regions** (`sys.regionrestriction`), which limits Azure for Students to a short list of regions.
- **Fix:** redeployed in **North Central US**, which is on the allowed list. (I also tried "Central US" first by mistake, which is a different region and also blocked.)
- **Lesson:** when a deployment fails with no details, the activity log and policy assignments say why. Student and enterprise subscriptions often restrict regions, sizes or SKUs.

### Default VM size not available

- **Symptom:** the VM wizard's default size, `Standard_D2s_v3`, showed `NotAvailableForSubscription` in North Central US.
- **Fix:** picked **Standard_B2als_v2** (2 vCPU, 4 GiB). It's also far cheaper, about $34/month if left on 24/7 versus about $140.
- **Lesson:** B-series burstable sizes fit lab servers that are idle most of the time.

### PowerShell cmdlet "not recognized"

- **Symptom:** `Install-WindowsFeature` returned "is not recognized as an internal or external command".
- **Cause:** the window was the classic Command Prompt (`C:\>`), not PowerShell (`PS C:\>`).
- **Fix:** ran `powershell` first, or opened **Windows PowerShell (Admin)** from the Start menu.

### RDP rule change didn't stick

- **Symptom:** after editing the RDP inbound rule, the network settings page still showed `Source: Any` with a warning icon.
- **Fix:** reopened the rule, set **Source → My IP address**, saved, and waited for the "Updated security rule" notification before leaving the page.
- **Lesson:** verify security changes from the summary view, not just the edit panel.

## 2026-11-10 · Phase 2

### Couldn't RDP right after starting the VM

- **Symptom:** RDP failed even though DC01 showed **Running** and my IP matched the NSG rule. The portal warned "virtual machine agent status is not ready".
- **Investigation:** **Boot diagnostics → Screenshot** showed Windows sitting at the lock screen, so the OS was up. It had simply still been booting when I first tried.
- **Lesson:** "Running" in the portal means the VM is powered on, not that Windows is ready. Boot diagnostics shows what the console looks like without needing RDP.

### Script failed with "Cannot bind argument to parameter 'Path' because it is an empty string"

- **Cause:** `New-LabUsers.ps1` used `$PSScriptRoot` in its `param()` default values. Windows PowerShell 5.1 (the version built into Windows Server 2022) leaves it empty there, while PowerShell 7 fills it in.
- **Fix:** passed `-CsvPath` and `-LogPath` explicitly, then changed the script to resolve its default paths after the `param()` block ([commit](https://github.com/tbabaria24-bit/azure-homelab/commits/main/scripts/phase2/New-LabUsers.ps1)).
- **Lesson:** test admin scripts on the PowerShell version the servers actually run.

## 2026-11-17 · Phase 2

### Domain users couldn't sign in over Remote Desktop with a "must change password" flag

- **Cause:** Remote Desktop uses Network Level Authentication (NLA), which authenticates before the session starts. An account flagged to change its password at next logon can't complete that step.
- **Fix:** as the help desk, reset the password with `Set-ADAccountPassword` and cleared the flag with `Set-ADUser -ChangePasswordAtLogon $false`. Domain users also needed to be added to WS01's local **Remote Desktop Users** group.

### Lockout event 4740 showed a blank "Caller Computer Name"

- **Observation:** the lockout was logged on DC01, but the field that normally names the source computer was empty.
- **Why:** the failed attempts came through RDP with NLA, which doesn't pass the client's workstation name to the domain controller.
- **Next step in a real investigation:** check failed-logon events (4625) on WS01 for the source network address. I'll collect these centrally once the SIEM is running in Phase 3.

## 2026-11-18 · Phase 3

### VM wizard silently picked a new network and expensive disks

- **Symptom:** the Review tab for LNX01 showed `Virtual network: (new) vnet-northcentralus-1` and `OS disk type: StandardSSD_ZRS`.
- **Fix:** before creating, switched to `vnet-homelab` / `snet-servers` and Standard SSD **LRS**. Otherwise LNX01 couldn't have reached DC01 or WS01.
- **Lesson:** always read the Review tab line by line; look for `(new)`.

### Wazuh install took about 20 minutes

- The installer expects 4 vCPUs; on 2 vCPUs the indexer start-up step was slow. Keeping the SSH session alive (Mac awake) mattered, since a dropped session can break the install.

### "Backdoor" account creation failed the first time

- The attacker's password didn't meet the domain policy (12+ characters, complex) set in Phase 2, so the account was never created. A second attempt with a compliant password succeeded and Wazuh raised **Domain Admins Group Changed (level 12)**.

### False positive: "possible pass-the-hash"

- Wazuh rule 92652 flagged my own NTLM RDP sign-in. I verified the source IP and account were mine, then documented a tuning approach in the [incident report](incident-report-2026-11-18.md).
