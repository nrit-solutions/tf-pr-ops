resource "azurerm_resource_group" "example" {
  name     = "rg-tfpr-example"
  location = "westeurope"

  tags = {
    managed_by = "terraform-pr-ops"
  }
}
