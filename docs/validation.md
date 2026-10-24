# Validation record

Prepared 23 October 2026, America/Chicago.

This is reconstructed source, not an export of the original local project. The implementation includes 18 Python tests, four Terraform mock plan tests, PowerShell syntax parsing, recursive formatting and provider schema validation for both environment roots and the module. GitHub CI is the independent published result; consult the linked workflow for the exact commit and conclusion.

Offline tests exercise subnet topology, secret placement, example deployment rejection, computer name/disk inputs, plan completeness, destructive action rejection, private NIC configuration, Bastion placement, Trusted Launch, optional IIS and rejected module inputs. They do not establish Azure deployment acceptance or Azure DevOps server-side YAML expansion.

A live acceptance record should capture the approved plan/run ID, exact commit, source/agent versions, state key, Azure provisioning result, Bastion session verification, guest IIS response, disk size and patch assessment. Never include passwords, WIF bearer tokens, full state or binary plan contents in a public validation record.

Implementation commit `1bb7499a93121670dad5a0908f865b5bbecde068` passed hosted [run 40060646282](https://github.com/dotman01k/azure-automated-pipeline/actions/runs/40060646282): 18 Python tests, four Terraform mock tests, all three configuration validations and PowerShell syntax parsing. A subsequent CI step also exercises the PowerShell validation entry point for both roots; check the latest workflow result for that addition. Local provider execution did not complete in the preparation runtime; hosted results are the validation evidence for the provider checks.
