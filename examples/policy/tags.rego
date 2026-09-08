# Starter conftest policy for the tf-pr-ops policy gate. NOT LOADED.
#
# This file lives under examples/ and the gate never reads it. The gate globs
# <consumer repo>/policy/*.rego, so copy it into a policy/ directory at your
# repository root and adapt it:
#
#   mkdir -p policy && cp .tfpr-engine/examples/policy/tags.rego policy/
#
# It runs against `terraform show -json`, which the gate exposes as
# $TFPR_PLANJSON. A `warn` reports without gating; a `deny` fails the hook and
# blocks the merge gate. Start with `warn`, clear the findings, then promote.
#
# Four things about plan JSON are load-bearing. All four fail the same way: the
# policy looks right, the gate reports clean, and nothing was checked.
#
#   1. A rule that matches NO resource reports a clean gate, which is
#      indistinguishable from a rule that passed. This is the easiest way to
#      ship a policy that does nothing. Modules increasingly declare
#      `azapi_resource` rather than a typed `azurerm_*` resource, and a rule
#      keyed on the azurerm type then matches nothing at all. Match both, as
#      is_storage_account does below.
#   2. `change.actions` is an ARRAY. A replace is ["delete","create"] and an
#      unchanged resource is ["no-op"]. Test membership with `in`, never
#      actions[0].
#   3. `change.after` is null on a destroy. Guard it, or the rule evaluates to
#      undefined and a deny silently fails open.
#   4. An empty string is a present value. `not tags.owner` passes a tag set to
#      "", so check the value, not just the key.
#
# Test a rule against a plan you know should fail before trusting a pass:
#
#   conftest test --policy policy --namespace main <plan.json>
#
# The gate tests the `main` namespace by default, so keep `package main` (or
# set CONFTEST_NAMESPACE to match a different package).
package main

import rego.v1

# Both provider shapes for the same resource. For an azapi resource the
# Terraform type is always `azapi_resource`; the ARM type identifying what it
# actually is lives in change.after.type, versioned with an @suffix, so match
# on the prefix.
is_storage_account(resource) if resource.type == "azurerm_storage_account"

is_storage_account(resource) if {
	resource.type == "azapi_resource"
	startswith(resource.change.after.type, "Microsoft.Storage/storageAccounts@")
}

# Resources this plan creates or changes. A destroy carries a null `after` and
# a no-op is not worth gating, so both drop out here rather than in every rule.
managed_storage_accounts contains resource if {
	resource := input.resource_changes[_]
	not "delete" in resource.change.actions
	not "no-op" in resource.change.actions
	resource.change.after != null
	is_storage_account(resource)
}

has_value(resource, key) if {
	value := resource.change.after.tags[key]
	value != ""
}

deny contains msg if {
	resource := managed_storage_accounts[_]
	not has_value(resource, "owner")
	msg := sprintf("%s: storage accounts must set a non-empty 'owner' tag", [resource.address])
}

# Advisory: surface any resource that will be destroyed, so a destructive plan
# is obvious in review. Deliberately not scoped to one resource type.
warn contains msg if {
	resource := input.resource_changes[_]
	"delete" in resource.change.actions
	msg := sprintf("%s will be destroyed", [resource.address])
}
