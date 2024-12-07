resource "azurerm_resource_group" "rg" {
  name     = "vmss-autoscaling-rg"
  location = "Canada East"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "autoscaling-vnet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "autoscaling-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a Linux Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "autoscaling-vmss"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard_DS1_v2"
  instances           = 2

  admin_username = "azureuser"
  admin_password = "Password@e123!"
  disable_password_authentication = false

  
  
  # Image for the VMSS
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # OS Disk Configuration
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # Network Configuration
  network_interface {
    name = "networkProfile"
    primary                   = true
    
    enable_accelerated_networking = false

    ip_configuration {
      name = "ip_config"
      primary = true
      subnet_id = azurerm_subnet.subnet.id
    }
  }

  # Tags for the resource
  tags = {
    environment = "testing"
  }
}

# Optional: Autoscaling Configuration (if needed)
resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "vmss-autoscale"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "default-autoscale-profile"

    capacity {
      minimum = 1
      maximum = 5
      default = 2
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 30
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = 1
        cooldown  = "PT1M"
      }
    }
  }
}