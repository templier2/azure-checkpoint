locals {
  regex_second_frontend_subnet_prefix = regex(local.regex_valid_network_cidr, var.second_frontend_subnet_prefix) == var.second_frontend_subnet_prefix ? 0 : "Variable [second_frontend_subnet_prefix] must be a valid address in CIDR notation."
  // Will fail if var.second_frontend_subnet_prefix is invalid
}

variable "second_frontend_subnet_prefix" {
  description = "Address prefix to be used for network frontend subnet"
  type        = string
}

resource "azurerm_subnet" "apache" {
  name                 = "Office-Subnet"
  resource_group_name  = module.common.resource_group_name
  virtual_network_name = module.vnet.vnet_name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "apache" {
  count               = 2
  name                = "apache${count.index + 1}"
  location            = module.common.resource_group_location
  resource_group_name = module.common.resource_group_name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = count.index == 1 ? module.gw-vnet.vnet_subnets[1] : azurerm_subnet.apache.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "apache" {
  count               = 2
  name                = "apache${count.index + 1}"
  location            = module.common.resource_group_location
  resource_group_name = module.common.resource_group_name
  size                = "Standard_B1ls"
  admin_username      = "${var.admin_username}-user"
  network_interface_ids = [
    azurerm_network_interface.apache[count.index].id,
  ]

  admin_ssh_key {
    username   = "${var.admin_username}-user"
    public_key = file("${path.module}/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "apache" {
  count                = 2
  name                 = "apache${count.index + 1}"
  virtual_machine_id   = azurerm_linux_virtual_machine.apache[count.index].id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
 {
  "commandToExecute": "apt update && apt install apache2 -y"
 }
SETTINGS
}