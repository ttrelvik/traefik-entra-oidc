resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-gateway"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-gateway"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_public_ip" "vm_ip" {
  name                = "pip-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_address_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-gateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-gateway"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

data "azurerm_dns_zone" "primary" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

resource "azurerm_dns_a_record" "temp" {
  name                = var.dns_record_name
  zone_name           = data.azurerm_dns_zone.primary.name
  resource_group_name = data.azurerm_dns_zone.primary.resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.vm_ip.ip_address]
}

resource "azurerm_dns_a_record" "drupal_dev" {
  name                = "drupal-dev"
  zone_name           = data.azurerm_dns_zone.primary.name
  resource_group_name = data.azurerm_dns_zone.primary.resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.vm_ip.ip_address]
}


resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible_inventory.ini"
  content  = <<EOF
[swarm_manager]
${azurerm_public_ip.vm_ip.ip_address} ansible_user=${var.admin_username} ansible_ssh_private_key_file=${replace(var.ssh_public_key_path, ".pub", "")}
EOF
}

resource "azurerm_dns_cname_record" "traefik" {
  name                = "traefik"
  zone_name           = data.azurerm_dns_zone.primary.name
  resource_group_name = data.azurerm_dns_zone.primary.resource_group_name
  ttl                 = 300
  record              = "${var.dns_record_name}.${var.dns_zone_name}"
}

resource "azurerm_dns_cname_record" "auth" {
  name                = "auth"
  zone_name           = data.azurerm_dns_zone.primary.name
  resource_group_name = data.azurerm_dns_zone.primary.resource_group_name
  ttl                 = 300
  record              = "${var.dns_record_name}.${var.dns_zone_name}"
}
