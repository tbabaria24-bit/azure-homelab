resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "homelab-budget"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  time_period {
    start_date = var.budget_start_date
  }

  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 90
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  lifecycle {
    # Azure rejects changes to a budget's start date once it exists.
    ignore_changes = [time_period]
  }
}
