// Implementing feature block for Azure

provider "azurerm" {
  features {
   resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

//defining resource group

resource "azurerm_resource_group" "rg" {
  name     = "rg"
  location = "West Europe"
}

//defining virtual network

resource "azurerm_virtual_network" "vnet" {
  name                = "web-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location 		//referencing resource group location from rg resource defined above
  resource_group_name = azurerm_resource_group.rg.name 			//referencing resource group name from rg resource defined above
}

//defining azure subnets for web, app and DB

resource "azurerm_subnet" "web_subnet" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = ["10.0.3.0/24"]
  service endpoints = ["Microsoft.Sql"]
}


//defining public IP for web Linux

resource "azurerm_public_ip" "web_linuxvm_publicip" {
  name = "web-linuxvm-publicip"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  allocation_method = "Static"
  sku = "Standard"
 }

//defining NIC card for Linux VM in Web-vnet

resource "azurerm_network_interface" "web_nic" {
  name                = "web-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
	public_ip_address_id = azurerm_public_ip.web_linuxvm_publicip.id
 }
}

//define network security group for Linux Web VM

resource "azurerm_network_security_group" "web_nsg" {
  name                = "web-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

//Associate NSG and Linux VM NIC

resource "azurerm_network_interface_security_group_association" "web_nsg_associate" {
  depends_on = [ azurerm_network_security_rule.web_vmnic_nsg_rule_inbound]
  network_interface_id      = azurerm_network_interface.web_nic.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

//Create NSG Rules

locals {
  web_vmnic_inbound_ports_map = {
    "100" : "80", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "443",
    "120" : "22"
  } 
}

resource "azurerm_network_security_rule" "web_vmnic_nsg_rule_inbound" {
  for_each = local.web_vmnic_inbound_ports_map
  name                        = "Rule-Port-${each.value}"
  priority                    = each.key
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = each.value 
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.web_nsg.name
}
*/

//defining Linux VM resource for web

resource "azurerm_linux_virtual_machine" "web_vm" {
  name                = "web_vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.web_nic.id] //referencing nic id from web_nic resource defined above

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/ssh-keys/keys.pub") //reading public key from the local folder ssh keys
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

//defining NIC card for Linux VM in app-vnet

resource "azurerm_network_interface" "app_nic" {
  name                = "app-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

//defining Linux VM resource for app 

resource "azurerm_linux_virtual_machine" "app_vm" {
  name                = "app_vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.app_nic.id] //referencing nic id from app_nic resource defined above

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("${path.module}/ssh-keys/keys.pub") //reading public key from the local folder ssh keys
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

//Creating the SQL Server Instance and Database in DB tier

//DB Password

variable "mysql_db_password" {
  description = "Azure MySQL Database Administrator Password"
  type        = string
  sensitive   = true
}

resource "azurerm_mssql_server" "sql_server" {
  name 				  = "sql_server"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = sqladmin"
  administrator_login_password = var.mysql_db_password
  sku_name   = "GP_Gen5_2" 
  storage_mb = 5120
  version    = "8.0"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = false
  ssl_minimal_tls_version_enforced  = "TLSEnforcementDisabled" 
}

resource "azurerm_mysql_database" "db" {
  name                = var.mysql_db_schema
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.sql_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

// Azure MySQL Virtual Network Rule

resource "azurerm_mysql_virtual_network_rule" "mysql_virtual_network_rule" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_server.sql_server.name
  subnet_id           = azurerm_subnet.db_subnet.id
  
 }
