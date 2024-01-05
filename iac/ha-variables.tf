variable "ha_vnet_name" {
  description = "Virtual Network name"
  type        = string
}

variable "ha_address_space" {
  description = "The address space that is used by a Virtual Network."
  type        = string
  default     = "10.0.0.0/16"
}

variable "ha_subnet_prefixes" {
  description = "Address prefix to be used for netwok subnets"
  type        = list(string)
  default = [
    "10.0.0.0/24",
  "10.0.1.0/24"]
}

variable "use_public_ip_prefix" {
  description = "Indicates whether the public IP resources will be deployed with public IP prefix."
  type        = bool
  default     = false
}

variable "create_public_ip_prefix" {
  description = "Indicates whether the public IP prefix will created or an existing will be used."
  type        = bool
  default     = false
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "sku" {
  description = "SKU"
  type        = string
  default     = "Standard"
}

variable "existing_public_ip_prefix_id" {
  description = "The existing public IP prefix resource id."
  type        = string
  default     = ""
}

variable "enable_floating_ip" {
  description = "Indicates whether the load balancers will be deployed with floating IP."
  type        = bool
  default     = false
}

variable "lb_probe_name" {
  description = "Name to be used for lb health probe"
  default     = "health_prob_port"
}

variable "lb_probe_port" {
  description = "Port to be used for load balancer health probes and rules"
  default     = "8117"
}

variable "lb_probe_protocol" {
  description = "Protocols to be used for load balancer health probes and rules"
  default     = "tcp"
}

variable "lb_probe_unhealthy_threshold" {
  description = "Number of times load balancer health probe has an unsuccessful attempt before considering the endpoint unhealthy."
  default     = 2
}

variable "lb_probe_interval" {
  description = "Interval in seconds load balancer health probe rule perfoms a check"
  default     = 5
}

variable "availability_type" {
  description = "Specifies whether to deploy the solution based on Azure Availability Set or based on Azure Availability Zone."
  type        = string
  default     = "Availability Zone"
}

locals { // locals for 'availability_type' allowed values
  availability_type_allowed_values = [
    "Availability Zone",
    "Availability Set"
  ]
  // will fail if [var.availability_type] is invalid:
  validate_availability_type_value = index(local.availability_type_allowed_values, var.availability_type)
}

variable "number_of_vm_instances" {
  description = "Number of VM instances to deploy "
  type        = string
  default     = "2"
}

variable "ha_vm_size" {
  description = "Specifies size of Virtual Machine"
  type        = string
}

variable "ha_disk_size" {
  description = "Storage data disk size size(GB).Select a number between 100 and 3995"
  type        = string
}

variable "is_blink" {
  description = "Define if blink image is used for deployment"
  default     = true
}
variable "smart_1_cloud_token_a" {
  description = "Smart-1 Cloud Token, for configuring member A"
  type        = string
}

variable "smart_1_cloud_token_b" {
  description = "Smart-1 Cloud Token, for configuring member B"
  type        = string
}

resource "null_resource" "sic_key_invalid" {
  count = length(var.sic_key) >= 12 ? 0 : "SIC key must be at least 12 characters long"
}

variable "ha_template_name" {
  description = "Template name. Should be defined according to deployment type(ha, vmss)"
  type = string
  default = "ha_terraform"
}

variable "ha_template_version" {
  description = "Template version. It is reccomended to always use the latest template version"
  type = string
  default = "20210111"
}

variable "ha_installation_type" {
  description = "Installaiton type"
  type        = string
  default     = "cluster"
}

locals {
  # Validate both s1c tokens are used or both empty
  is_both_tokens_used     = length(var.smart_1_cloud_token_a) > 0 == length(var.smart_1_cloud_token_b) > 0
  validation_message_both = "To connect to Smart-1 Cloud, you must provide two tokens (one per member)"
  _                       = regex("^$", (local.is_both_tokens_used ? "" : local.validation_message_both))

  is_tokens_used = length(var.smart_1_cloud_token_a) > 0
  # Validate both s1c tokens are unqiue
  token_parts_a             = split(" ", var.smart_1_cloud_token_a)
  token_parts_b             = split(" ", var.smart_1_cloud_token_b)
  acutal_token_a            = local.token_parts_a[length(local.token_parts_a) - 1]
  acutal_token_b            = local.token_parts_b[length(local.token_parts_b) - 1]
  is_both_tokens_the_same   = local.acutal_token_a == local.acutal_token_b
  validation_message_unique = "Same Smart-1 Cloud token used for both memeber, you must provide unique token for each member"
  __                        = local.is_tokens_used ? regex("^$", (local.is_both_tokens_the_same ? local.validation_message_unique : "")) : ""
}