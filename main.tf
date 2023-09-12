terraform {
  required_providers {
    azurerm = {
        source = "hashicorp/azurerm"
        version = "3.69.0"
    }
  }
}


provider "azurerm" {
    
    # Configuration options
    subscription_id = "930b0843-6f87-476c-b4e5-4db055a4c1b5"
    tenant_id = "2f59ff7c-1b6c-4d8c-97f5-e1e9103f2f15"
    client_id = "691f1a95-125d-4e56-b2b0-6fdf790e4c1f"
    client_secret = "5Ry8Q~KjPUUgLIqCluESFftnakBpOKxNRBRoSbcw"
    features {}  
}

resource "azurerm_resource_group" "wsm_grp" {
    name = "RG2"
    location = "Central India"
  
}
locals {
  resource_group_name = "RG2"
  location = "Central India"
  vm_count = 2
  public_ip = 2
  
}

data "cloudinit_config" "linux_conf" {
  gzip = true
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content = "packages: ['nginx']"
  }

  
}



resource "azurerm_storage_account" "infra_storage" {
    name = "storagewashim"
    location = local.location
    resource_group_name = local.resource_group_name
    account_tier = "Standard"
    account_replication_type = "LRS"
    
    

    depends_on = [ 
        azurerm_resource_group.wsm_grp 
        ]
  
}
resource "azurerm_storage_container" "infra_container" {
    name = "containerwsm"
    storage_account_name = "storagewashim"
    container_access_type = "private"
    
    
    depends_on = [ 
        azurerm_storage_account.infra_storage

     ]
  
}

resource "azurerm_storage_blob" "blob_wsm" {
    name = "sample.txt"
    storage_account_name = "storagewashim"
    storage_container_name = "containerwsm"
    type = "Block"
    source = "sample.txt"
    

    depends_on = [ azurerm_storage_container.infra_container ]
   
    
  
}

resource "azurerm_virtual_network" "vnet_wsm" {

  name = "vnetwashim"
  location = local.location
  resource_group_name = local.resource_group_name
  address_space = ["10.0.0.0/16"]
  depends_on = [ azurerm_resource_group.wsm_grp ]

  
}

resource "azurerm_subnet" "subnet_wsm" {

  name = "subnetwashim"
  resource_group_name = local.resource_group_name
  virtual_network_name = "vnetwashim"
  address_prefixes = ["10.0.0.0/24"]
  depends_on = [ azurerm_virtual_network.vnet_wsm ]
    
  
}

/* resource "azurerm_network_security_group" "NSG_GRP" {
  name = "NSGWSM1"
  location = local.location
  resource_group_name = local.resource_group_name

  
}

resource "azurerm_subnet_network_security_group_association" "NSG_allocation" {
  subnet_id = azurerm_subnet.subnet_wsm.id
  network_security_group_id = azurerm_network_security_group.NSG_GRP.id
  
}
*/


resource "azurerm_public_ip" "IP_wsm" {

  count = local.public_ip
  name = "linuxpublic-${count.index}"
  resource_group_name = local.resource_group_name
  location = local.location
  allocation_method = "Dynamic"
  depends_on = [ azurerm_resource_group.wsm_grp ]

}
  
resource "azurerm_network_interface" "network_wsm" {

  name = "vmwsm-nic-${count.index}"
  count = local.vm_count
  location = local.location
  resource_group_name = local.resource_group_name
  ip_configuration {
    name = "IPconfigwsm-${count.index}"
    subnet_id = azurerm_subnet.subnet_wsm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.IP_wsm[count.index].id
    


  }
  depends_on = [ azurerm_virtual_network.vnet_wsm,
  azurerm_public_ip.IP_wsm,
  azurerm_subnet.subnet_wsm ]
  
}

resource "azurerm_linux_virtual_machine" "VM_WSM" {

  name = "VMwsm-${count.index}"
  count = local.vm_count
  resource_group_name = local.resource_group_name
  location = local.location
  size = "Standard_B1s"
  admin_username = "shubham"
  admin_password = "Shubham@123"
  disable_password_authentication = false
  custom_data = data.cloudinit_config.linux_conf.rendered
  network_interface_ids = [
    azurerm_network_interface.network_wsm[count.index].id
    ]

    os_disk {
      caching = "ReadWrite"
      storage_account_type = "Standard_LRS"
    }

    source_image_reference {
      publisher = "Canonical"
      offer = "0001-com-ubuntu-server-focal"
      sku = "20_04-lts"
      version = "latest"
    }

    depends_on = [ azurerm_network_interface.network_wsm,
    azurerm_virtual_network.vnet_wsm ]
  
}
