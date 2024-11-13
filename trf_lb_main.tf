terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.9.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = ""
}

# Resourse groupe create
resource "azurerm_resource_group" "rg" {
  name     = "course-resource-group"
  location = "West Europe"
}

# Network
resource "azurerm_virtual_network" "vnet" {
  name                = "course-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "course-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# NSG
resource "azurerm_network_security_group" "nsg" {
  name                = "course-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

# ssh 
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "95.46.143.103/32"
    destination_address_prefix = "*"
  }
}

# Connect subnet and NSG
resource "azurerm_subnet_network_security_group_association" "subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# IP 
resource "azurerm_public_ip" "pip" {
  name                = "IPForLB-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Availability Set
resource "azurerm_availability_set" "avset" {
  name                         = "avalset"
  location                     = azurerm_resource_group.rg.location
  resource_group_name          = azurerm_resource_group.rg.name
  managed                      = true
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
}

# Create LB
resource "azurerm_lb" "lb" {
  name                = "CourseLoadBalancer"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "LBIPAddress"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

# Health probe
resource "azurerm_lb_probe" "prb" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "ssh-running-probe"
  port            = 22
  protocol        = "Tcp"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Backend pool
resource "azurerm_lb_backend_address_pool" "lbpool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "BackEndAddressPool"
}

# LB rule
resource "azurerm_lb_rule" "lbrule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  frontend_ip_configuration_name = "LBIPAddress"
  probe_id                       = azurerm_lb_probe.prb.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lbpool.id]
  disable_outbound_snat          = true
}

# NAT rule
resource "azurerm_lb_nat_rule" "natr" {
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "SSHAccess"
  protocol                       = "Tcp"
  frontend_port_start            = 2200
  frontend_port_end              = 2201
  backend_port                   = 22
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lbpool.id
  frontend_ip_configuration_name = "LBIPAddress"
}

# Out rule
resource "azurerm_lb_outbound_rule" "out" {
  name                    = "OutboundRule"
  loadbalancer_id         = azurerm_lb.lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbpool.id
  frontend_ip_configuration {
    name = "LBIPAddress"
  }
}

# NICs
resource "azurerm_network_interface" "nic1" {
  name                = "course-nic1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic2" {
  name                = "course-nic2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# NICs association with LB pool (with ip_configuration_name)
resource "azurerm_network_interface_backend_address_pool_association" "lb_nic_as1" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbpool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "lb_nic_as2" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "ipconfig1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbpool.id
}

# Create VMs
resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "terrafrom-lesson-vm1"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic1.id]
  availability_set_id   = azurerm_availability_set.avset.id
  admin_password        = "Testpassword1"
  disable_password_authentication = false
  
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
  tags = {
    environment = "testing"
  }
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "terrafrom-lesson-vm2"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic2.id]
  availability_set_id   = azurerm_availability_set.avset.id
  admin_password        = "Testpassword1"
  disable_password_authentication = false
  
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
  tags = {
    environment = "testing"
  }
}

# Output the Public IP of the Load Balancer
output "load_balancer_public_ip" {
  value = azurerm_public_ip.pip
}
