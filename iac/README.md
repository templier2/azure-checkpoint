# Check Point CloudGuard IaaS Management Terraform deployment for Azure
Structure of a project
The basis of this configuration is a project on GitHub - https://github.com/CheckPointSW/CloudGuardIaaS/ (/terraform/azure)
Folder management-new-vnet is basis, it is taken as is.
Two other folders (high-availability-new-vnet and single-gateway-new-vnet) are merged and refactored to remove conflicts with same names. Single-gateway-new-net files have got a prefix "sgw-", high-availability files have got - "ha-".
All values were merged to the terraform.tfvars.

Note: default admin shell is changed to /bin/bash (it is needed for gateways' import).

Apache VMs need to be checked, currently it is unavailable from Interne.
After first deployment step mgmt_import_gw will fail.
You have to wait approx 20 minutes before running it again.