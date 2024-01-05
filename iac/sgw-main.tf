//********************** Networking **************************//
module "gw-vnet" {
  source = "../modules/vnet"

  vnet_name           = var.gw_vnet_name
  resource_group_name = module.common.resource_group_name
  location            = module.common.resource_group_location
  address_space       = var.gw_address_space
  subnet_prefixes     = [var.frontend_subnet_prefix, var.backend_subnet_prefix]
  subnet_names        = ["${var.single_gateway_name}-frontend-subnet", "${var.single_gateway_name}-backend-subnet"]
  nsg_id              = module.gw-network-security-group.network_security_group_id
}

module "gw-network-security-group" {
  source              = "../modules/network-security-group"
  resource_group_name = module.common.resource_group_name
  security_group_name = "${module.common.resource_group_name}-single-nsg"
  location            = module.common.resource_group_location
  security_rules = [
    {
      name                       = "AllowAllInBound"
      priority                   = "100"
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "*"
      source_port_ranges         = "*"
      destination_port_ranges    = "*"
      description                = "Allow all inbound connections"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
}

resource "azurerm_public_ip" "gw-public-ip1" {
  name                    = "${var.single_gateway_name}-ip1"
  location                = module.common.resource_group_location
  resource_group_name     = module.common.resource_group_name
  allocation_method       = var.vnet_allocation_method
  idle_timeout_in_minutes = 30
  domain_name_label = join("", [
    lower(var.single_gateway_name),
    "-",
  random_id.randomId.hex])
}

resource "azurerm_network_interface_security_group_association" "gw-security_group_association" {
  depends_on                = [azurerm_network_interface.gw-nic, module.gw-network-security-group.network_security_group_id]
  network_interface_id      = azurerm_network_interface.gw-nic.id
  network_security_group_id = module.gw-network-security-group.network_security_group_id
}

resource "azurerm_network_interface" "gw-nic" {
  depends_on = [
  azurerm_public_ip.gw-public-ip1]
  name                 = "${var.single_gateway_name}-eth0"
  location             = module.common.resource_group_location
  resource_group_name  = module.common.resource_group_name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = module.gw-vnet.vnet_subnets[0]
    private_ip_address_allocation = var.vnet_allocation_method
    private_ip_address            = cidrhost(var.frontend_subnet_prefix, 4)
    public_ip_address_id          = azurerm_public_ip.gw-public-ip1.id
  }
}

resource "azurerm_network_interface" "gw-nic1" {
  depends_on           = []
  name                 = "${var.single_gateway_name}-eth1"
  location             = module.common.resource_group_location
  resource_group_name  = module.common.resource_group_name
  enable_ip_forwarding = false

  ip_configuration {
    name                          = "ipconfig2"
    subnet_id                     = module.gw-vnet.vnet_subnets[1]
    private_ip_address_allocation = var.vnet_allocation_method
    private_ip_address            = cidrhost(var.backend_subnet_prefix, 4)
  }
}

//********************** Virtual Machines **************************//
resource "azurerm_virtual_machine" "single-gateway-vm-instance" {
  depends_on = [
    azurerm_network_interface.gw-nic,
  azurerm_network_interface.gw-nic1]
  location = module.common.resource_group_location
  name     = var.single_gateway_name
  network_interface_ids = [
    azurerm_network_interface.gw-nic.id,
  azurerm_network_interface.gw-nic1.id]
  resource_group_name           = module.common.resource_group_name
  vm_size                       = var.single_gateway_vm_size
  delete_os_disk_on_termination = module.common.delete_os_disk_on_termination
  primary_network_interface_id  = azurerm_network_interface.gw-nic.id

  identity {
    type = module.common.vm_instance_identity
  }

  dynamic "plan" {
    for_each = local.custom_image_condition ? [
    ] : [1]
    content {
      name      = var.sgw_vm_os_sku
      publisher = module.common.publisher
      product   = module.common.vm_os_offer
    }
  }

  boot_diagnostics {
    enabled     = module.common.boot_diagnostics
    storage_uri = module.common.boot_diagnostics ? join(",", azurerm_storage_account.vm-boot-diagnostics-storage.*.primary_blob_endpoint) : ""
  }

  os_profile {
    computer_name  = var.single_gateway_name
    admin_username = module.common.admin_username
    admin_password = module.common.admin_password
    custom_data = templatefile("${path.module}/sgw-init.sh", {
      installation_type              = var.gw_installation_type
      allow_upload_download          = module.common.allow_upload_download
      os_version                     = module.common.os_version
      template_name                  = var.gw_template_name
      template_version               = var.gw_template_version
      template_type                  = "terraform"
      is_blink                       = module.common.is_blink
      bootstrap_script64             = base64encode(var.bootstrap_script)
      location                       = module.common.resource_group_location
      admin_shell                    = var.admin_shell
      sic_key                        = var.sic_key
      management_GUI_client_network  = var.management_GUI_client_network
      smart_1_cloud_token            = var.smart_1_cloud_token
      enable_custom_metrics          = var.enable_custom_metrics ? "yes" : "no"
      serial_console_password_hash   = var.serial_console_password_hash
      maintenance_mode_password_hash = var.maintenance_mode_password_hash
    })
  }

  os_profile_linux_config {
    disable_password_authentication = local.SSH_authentication_type_condition

    dynamic "ssh_keys" {
      for_each = local.SSH_authentication_type_condition ? [
      1] : []
      content {
        path     = "/home/notused/.ssh/authorized_keys"
        key_data = file("${path.module}/azure_public_key")
      }
    }
  }

  storage_image_reference {
    id        = local.custom_image_condition ? azurerm_image.custom-image[0].id : null
    publisher = local.custom_image_condition ? null : module.common.publisher
    offer     = module.common.vm_os_offer
    sku       = var.sgw_vm_os_sku
    version   = module.common.vm_os_version
  }

  storage_os_disk {
    name              = var.single_gateway_name
    create_option     = module.common.storage_os_disk_create_option
    caching           = module.common.storage_os_disk_caching
    managed_disk_type = module.common.storage_account_type
    disk_size_gb      = var.sgw_disk_size
  }
}