terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "2.97.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "azure-rg" {
  name     = "azure-resources"
  location = "West Europe"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "azure-vn" {
  name                = "azure-network"
  resource_group_name = azurerm_resource_group.azure-rg.name
  location            = azurerm_resource_group.azure-rg.location
  address_space       = ["10.10.0.0/16"]

  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet" "azure-subnet" {
  name                 = "azure-subnet-1"
  resource_group_name  = azurerm_resource_group.azure-rg.name
  virtual_network_name = azurerm_virtual_network.azure-vn.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "azure-security" {
  name                = "azure-security"
  location            = azurerm_resource_group.azure-rg.location
  resource_group_name = azurerm_resource_group.azure-rg.name

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_rule" "azure-dev-rule" {
  name                        = "azure-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.azure-rg.name
  network_security_group_name = azurerm_network_security_group.azure-security.name
}

resource "azurerm_subnet_network_security_group_association" "azure-sga" {
  subnet_id                 = azurerm_subnet.azure-subnet.id
  network_security_group_id = azurerm_network_security_group.azure-security.id
}

resource "azurerm_public_ip" "azure-ip" {
  name                = "azure-ip"
  resource_group_name = azurerm_resource_group.azure-rg.name
  location            = azurerm_resource_group.azure-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_interface" "azure-nic" {
  name                = "azure-nic"
  location            = azurerm_resource_group.azure-rg.location
  resource_group_name = azurerm_resource_group.azure-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azure-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.azure-ip.id
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_linux_virtual_machine" "azure-vm"{
  name = "internal"
  resource_group_name = azurerm_resource_group.azure-rg.name
  location = azurerm_resource_group.azure-rg.location
  size = "Standard_F2"
  admin_username = "projectadmin"

  network_interface_ids = [
    azurerm_network_interface.azure-nic.id
  ]

  admin_ssh_key {
    username =  "projectadmin"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}