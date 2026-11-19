# Phase 4 – The lab as code (Terraform)

The [`terraform/`](../terraform) folder rebuilds the whole lab: network, firewalls, DC01 (auto-promoted domain controller), WS01 (auto-joined Windows 11), LNX01 (Wazuh installed on first boot), auto-shutdown and a budget.

## Run it from Azure Cloud Shell (nothing to install)

1. Azure portal → **`>_`** (Cloud Shell) → **Bash** → *No storage account required* → subscription **Azure for Students**.
2. Select the right subscription and check the quota:

```bash
az account set --subscription "Azure for Students"
az vm list-usage --location northcentralus -o table | grep -iE "regional|basv2"
```

The full lab needs **6 free vCPUs** (3 VMs × 2). Set `deploy_ws01 = false` and/or `deploy_lnx01 = false` to build less.

3. Get the code and configure it:

```bash
git clone https://github.com/tbabaria24-bit/azure-homelab.git && cd azure-homelab/terraform
ssh-keygen -t ed25519 -f ~/.ssh/homelab_tf -N "" -q
cat > terraform.tfvars <<EOT
subscription_id = "$(az account show --query id -o tsv)"
allowed_ip      = "<your public IP>"
alert_email     = "<your email>"
EOT
read -s -p "Admin password: " TF_VAR_admin_password; echo; export TF_VAR_admin_password
read -s -p "DSRM password: " TF_VAR_dsrm_password; echo; export TF_VAR_dsrm_password
```

4. Plan, build, and tear down:

```bash
terraform init
terraform plan          # expect: Plan: 30 to add, 0 to change, 0 to destroy
terraform apply         # about 15 minutes, plus a 12-minute wait for the domain before WS01 joins
terraform output        # public IPs, SSH command, Wazuh URL
terraform destroy       # removes everything in rg-homelab-tf
```

## Notes

- Everything goes into a separate resource group (`rg-homelab-tf`), so it never touches the hand-built `rg-homelab`.
- Wazuh takes about 20 minutes after LNX01 boots. Follow it with `sudo tail -f /var/log/wazuh-install.log`; get the admin password with `sudo tar -O -xvf /root/wazuh-install-files.tar wazuh-install-files/wazuh-passwords.txt`.
- After the build, run [`scripts/phase2/New-LabUsers.ps1`](../scripts/phase2/New-LabUsers.ps1) on DC01 to create the OUs and users, and enroll the Wazuh agents as in [Phase 3](phase3-wazuh-siem.md).
