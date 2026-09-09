variable "resource_group_name" {
  description = "Resource group the self-test identity can read. The bootstrap creates it as rg-cicd-selftest-<location_short>."
  type        = string
  default     = "rg-cicd-selftest-weu"
}
