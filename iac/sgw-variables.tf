variable "single_gateway_name" {
  description = "Single Gateway name"
  type        = string
}

variable "single_gateway_vm_size" {
  description = "Specifies size of Single Gateway"
  type        = string
}

variable "sgw_disk_size" {
  description = "Storage data disk size size(GB) for Single Gateway.Select a number between 100 and 3995"
  type        = string
}

variable "sgw_vm_os_sku" {
  description = "The sku of the single gateway image to be deployed."
  type        = string
}

variable "gw_vnet_name" {
  description = "Single gateway Virtual Network name"
  type        = string
}

variable "gw_address_space" {
  description = "The address space that is used by a Virtual Network."
  type        = string
  default     = "172.16.0.0/24"
}

variable "frontend_subnet_prefix" {
  description = "Address prefix to be used for network frontend subnet"
  type        = string
}

variable "backend_subnet_prefix" {
  description = "Address prefix to be used for network backend subnet"
  type        = string
}

locals {
  regex_frontend_subnet_prefix = regex(local.regex_valid_network_cidr, var.frontend_subnet_prefix) == var.frontend_subnet_prefix ? 0 : "Variable [frontend_subnet_prefix] must be a valid address in CIDR notation."
  // Will fail if var.frontend_subnet_prefix is invalid
  regex_backend_subnet_prefix = regex(local.regex_valid_network_cidr, var.backend_subnet_prefix) == var.backend_subnet_prefix ? 0 : "Variable [backend_subnet_prefix] must be a valid address in CIDR notation."
  // Will fail if var.backend_subnet_prefix is invalid
}

variable "sic_key" {
  description = "Storage data disk size size(GB).Select a number between 100 and 3995"
  type        = string
}

variable "smart_1_cloud_token" {
  description = "Storage data disk size size(GB).Select a number between 100 and 3995"
  type        = string
}

variable "enable_custom_metrics" {
  description = "Indicates whether CloudGuard Metrics will be use for Cluster members monitoring"
  type        = string
}

variable "gw_installation_type" {
  description = "installation type"
  type        = string
  default     = "gateway"
}

variable "gw_template_name" {
  description = "Template name. Should be defined according to deployment type(mgmt, ha, vmss, sg)"
  type        = string
  default     = "single"
}

variable "gw_template_version" {
  description = "Template version. It is recommended to always use the latest template version"
  type        = string
  default     = "20230629"
}

variable "gw_netmask_length" {
  description = "Length of netmask for all Single Gateway Subnets"
  type        = string
}