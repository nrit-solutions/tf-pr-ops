# The smallest thing a plan-only identity can plan: a user-assigned identity
# with no role assignments (free, no data plane) inside a resource group the
# identity can only read. The group is created by the platform bootstrap, so
# the Reader assignment exists before the first plan.
#
# Also the unit an engine pull request touches when it changes projects.yml:
# the merge gate counts that file as Terraform and wants a unit planned.

data "azurerm_resource_group" "selftest" {
  name = var.resource_group_name
}

resource "azurerm_user_assigned_identity" "example" {
  name                = "id-tfpr-selftest-example"
  resource_group_name = data.azurerm_resource_group.selftest.name
  location            = data.azurerm_resource_group.selftest.location

  tags = {
    managed_by = "terraform-pr-ops"
    purpose    = "engine-selftest"
  }
}
