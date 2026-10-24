# Moving the original Windows project into the collection

The previous repository layout had top-level modules/windows-vm and environments/dev|prod. Those files now live under services/virtual-machines. The module address remains module.windows_vm, and the live runner preserves windows-vm-dev.tfstate and windows-vm-prod.tfstate keys. No state migration is automatically performed.

Existing Azure DevOps pipeline users must update their entry point/root selection and variable group/environment references. Old windows-vm-dev|prod variable groups and deployment environments become compute-virtual-machines-dev|prod. The password input changes from VM_ADMIN_PASSWORD to the secret JSON contract TF_SECRET_JSON. Recreate the same approval/branch/exclusive-lock controls before authorizing the updated pipeline. Do not assume a renamed YAML reference carries protection settings over.

The new common runner accepts -Service as well as -Environment and -Operation. Direct calls must use the new signature. New service roots use compute/<service>/<environment>.tfstate; do not copy the Windows key to a new service.

The earlier README described reconstructed source, not a copy of the unavailable local InfraProject repository. That provenance still applies. Before reusing any real state, inventory exact resource addresses, names, image/settings and provider versions. Folder movement alone is not evidence that a live environment will plan no changes. Review the full plan and retain state versions.
