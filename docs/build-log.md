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
