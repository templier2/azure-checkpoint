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
  virtual_network_name = module.ha-vnet.vnet_name
  address_prefixes     = ["192.168.0.0/27"]
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

resource "azurerm_subnet_network_security_group_association" "ha_subnet3" {
  subnet_id = azurerm_subnet.apache.id
  network_security_group_id = module.ha-network-security-group.network_security_group_id
}

resource "azurerm_route_table" "ha_subnet3" {
  name = "${var.cluster_name}-subnet3-route"
  location = var.location
  resource_group_name = var.resource_group_name

  route {
    name = "Local-Subnet"
    address_prefix = azurerm_subnet.apache.address_prefixes[0]
    next_hop_type = "VnetLocal"
  }
  route {
    name = "To-Out"
    address_prefix = "0.0.0.0/0"
    next_hop_type = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.backend-lb.private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "ha_subnet3" {
  subnet_id = azurerm_subnet.apache.id
  route_table_id = azurerm_route_table.ha_subnet3.id
}

resource "azurerm_linux_virtual_machine" "apache" {
  depends_on = [
    azurerm_virtual_machine.vm-instance-availability-zone,
    azurerm_virtual_machine.vm-instance-availability-set,
    azurerm_virtual_machine.single-gateway-vm-instance
  ]
  count               = 2
  name                = "apache${count.index + 1}"
  location            = module.common.resource_group_location
  resource_group_name = module.common.resource_group_name
  size                = "Standard_B1ls"
  admin_username      = "${var.admin_username}-user"
  admin_password      = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.apache[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "bitnami"
    offer     = "tom-cat"
    sku       = "7-0"
    version   = "latest"
  }
  plan {
    publisher = "bitnami"
    product = "tom-cat"
    name = "7-0"
  }
}

resource "null_resource" "mgmt_import_gw" {
  depends_on = [
    azurerm_virtual_machine.vm-instance-availability-zone,
    azurerm_virtual_machine.vm-instance-availability-set,
    azurerm_virtual_machine.single-gateway-vm-instance,
    azurerm_virtual_machine.mgmt-vm-instance
  ]
  connection {
    type     = "ssh"
    host     = azurerm_public_ip.public-ip.ip_address
    user     = "admin"
    password = var.admin_password
    timeout  = "5m"
  }

  provisioner "remote-exec" {
    on_failure = fail
    inline = [
      "mgmt_cli -r true add simple-gateway name ${var.single_gateway_name} ipv4-address ${azurerm_public_ip.gw-public-ip1.ip_address} one-time-password ${var.sic_key} interfaces.0.name 'eth0' interfaces.0.anti-spoofing false interfaces.0.ip-address ${azurerm_network_interface.gw-nic.private_ip_address} interfaces.0.ipv4-mask-length ${var.gw_netmask_length} interfaces.0.topology 'EXTERNAL' interfaces.1.name 'eth1' interfaces.1.anti-spoofing false interfaces.1.ip-address ${azurerm_network_interface.gw-nic1.private_ip_address} interfaces.1.ipv4-mask-length ${var.gw_netmask_length} interfaces.2.name 'eth2' interfaces.2.anti-spoofing false interfaces.2.ip-address ${azurerm_network_interface.gw-nic2.private_ip_address} interfaces.2.ipv4-mask-length ${var.gw_netmask_length}",
      "mgmt_cli -r true add simple-cluster name ${var.cluster_name} cluster-mode 'cluster-xl-ha' ip-address ${azurerm_public_ip.cluster-vip.ip_address} members.1.name ${var.cluster_name}1 members.1.one-time-password ${var.sic_key} members.1.ip-address ${azurerm_public_ip.ha-public-ip.0.ip_address} members.2.name ${var.cluster_name}2 members.2.one-time-password ${var.sic_key} members.2.ip-address ${azurerm_public_ip.ha-public-ip.1.ip_address} interfaces.1.name eth0 interfaces.1.interface-type cluster interfaces.1.ip-address ${azurerm_public_ip.cluster-vip.ip_address} interfaces.1.network-mask 255.255.255.255 interfaces.1.topology EXTERNAL interfaces.1.anti-spoofing true interfaces.2.name eth1 interfaces.2.interface-type 'cluster + sync' interfaces.2.ip-address ${azurerm_lb.backend-lb.private_ip_address} interfaces.2.ipv4-mask-length ${var.gw_netmask_length} interfaces.2.topology INTERNAL interfaces.2.anti-spoofing true interfaces.2.topology-settings.interface-leads-to-dmz false members.1.interfaces.1.name eth0 members.1.interfaces.1.ip-address ${azurerm_network_interface.nic_vip.private_ip_address} members.1.interfaces.1.ipv4-mask-length ${var.gw_netmask_length} members.1.interfaces.2.name eth1 members.1.interfaces.2.ip-address ${azurerm_network_interface.ha-nic1.0.private_ip_address} members.1.interfaces.2.ipv4-mask-length ${var.gw_netmask_length} members.2.interfaces.1.name eth0 members.2.interfaces.1.ip-address ${azurerm_network_interface.ha-nic.private_ip_address} members.2.interfaces.1.ipv4-mask-length ${var.gw_netmask_length} members.2.interfaces.2.name eth1 members.2.interfaces.2.ip-address ${azurerm_network_interface.ha-nic1.1.private_ip_address} members.2.interfaces.2.ipv4-mask-length ${var.gw_netmask_length}"
    ]
  }
}
