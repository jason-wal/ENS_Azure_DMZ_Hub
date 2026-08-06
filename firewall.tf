locals {
  lb_idle_timeout   = "30"  # between 4 minutes and 100 minutes
  tcp_reset_enabled = true   # true of false 
  lb_probe_protocol = "Tcp"
  lb_probe_port     = "80"
  lb_probe_interval = "10"
  lb_probe_count    = "3"



}



#
#---------------------------------------------------------
# Create FW Resource Group
#-------------------------------------------------------------
#

resource "azurerm_resource_group" "fw_rsg" {
    name     = "${var.prefix}_fw_rsg"
    location = var.az_reg
    tags     = var.tags 
}

#
#---------------------------------------------------------
# Create FW Storage Accounts
#-------------------------------------------------------------
#
resource "azurerm_storage_account" "fw1" {
    name                                = replace(lower("${var.prefix}fw1"),"_", "" )
    resource_group_name                 = azurerm_resource_group.fw_rsg.name
    location                            = var.az_reg
    account_tier                        = "Standard" # Standard or Premium
    account_replication_type            = "LRS"
    account_kind                        = "StorageV2"
    access_tier                         = "Hot"
    cross_tenant_replication_enabled    = true
    tags                                = var.tags
    min_tls_version                     = var.strg_tls_min_ver # "TLS1_2"
    dns_endpoint_type                   = "Standard"

    network_rules {
        default_action              = "Deny"                         
        ip_rules                    = [ "199.128.0.0/11", "150.120.0.0/16"  ]
        bypass                      = [ "AzureServices", ]
    }    
}

resource "azurerm_storage_account" "fw2" {
    name                                = replace(lower("${var.prefix}fw2"),"_", "" )
    resource_group_name                 = azurerm_resource_group.fw_rsg.name
    location                            = var.az_reg
    account_tier                        = "Standard" # Standard or Premium
    account_replication_type            = "LRS"
    account_kind                        = "StorageV2"
    access_tier                         = "Hot"
    cross_tenant_replication_enabled    = true
    tags                                = var.tags
    min_tls_version                     = var.strg_tls_min_ver # "TLS1_2"
    dns_endpoint_type                   = "Standard"    

    network_rules {
        default_action              = "Deny"                         
        ip_rules                    = [ "199.128.0.0/11", "150.120.0.0/16"  ]
        bypass                      = [ "AzureServices", ]
    }    
}



#
#---------------------------------------------------------
# Create FW Availability Set  --- really not needed
#-------------------------------------------------------------
#

resource "azurerm_availability_set" "this" {
    name                            = "${var.prefix}_fw_Avail_Set"
    location                        = var.az_reg
    resource_group_name             = azurerm_resource_group.fw_rsg.name
    managed                         = true
    platform_fault_domain_count     = 1
    platform_update_domain_count    = 1
    tags                            = var.tags 
}

/*
######################################################################################
#
#         Create NSG for MGMT
#
######################################################################################

resource "azurerm_network_security_group" "fw_nsg" {
  name                = "${var.prefix}_fw_NSG"
  location            = var.az_reg
  resource_group_name = azurerm_resource_group.fw_rsg.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "fxp0_nsg_rule" {
  for_each = var.vSRX_fxp0_NSG_Rules
    name                            = each.key
    priority                        = each.value[ "priority" ]
    direction                       = each.value[ "direction" ]
    access                          = each.value[ "access" ]
    protocol                        = each.value[ "protocol" ]
    source_port_ranges              = each.value[ "source_port_ranges" ]
    destination_port_ranges         = each.value[ "destination_port_ranges" ]
    source_address_prefixes         = each.value[ "source_address_prefixes" ]
    destination_address_prefixes    = each.value[ "destination_address_prefixes" ]
    resource_group_name             = azurerm_resource_group.fw_rsg.name
    network_security_group_name     = azurerm_network_security_group.fxp0_nsg.name
}
*/

#
#---------------------------------------------------------
# Create FW1 Interfaces
#-------------------------------------------------------------
#
resource "azurerm_network_interface" "fw1_int" {
  for_each = var.fw1_interfaces
    name                              = "${var.prefix}_fw1_${each.key}"
    location                          = var.az_reg
    resource_group_name               = azurerm_resource_group.fw_rsg.name
    ip_forwarding_enabled             = true
    accelerated_networking_enabled    = true
    tags                              = var.tags 

    ip_configuration {
        name                            = "${var.prefix}_fw1_${each.key}_v4"
        subnet_id                       = azurerm_subnet.this[each.value["sub"]].id
        private_ip_address_allocation   = "Static"
        private_ip_address              = each.value["v4_IP"]
        primary                         = true
        private_ip_address_version      = "IPv4"
    }

    ip_configuration {
        name                            = "${var.prefix}_fw1_${each.key}_v6"
        subnet_id                       = azurerm_subnet.this[each.value["sub"]].id
        private_ip_address_allocation   = "Static"
        private_ip_address_version      = "IPv6"
        private_ip_address              = each.value["v6_IP"]
    }

/*
    dynamic "ip_configuration" {
        for_each = contains( [ "MGMT", "HA" ], each.key ) ? [1] : []
          content {
            name                            =  "${var.prefix}_fw1_${each.key}_v6"
            subnet_id                       = azurerm_subnet.this[each.value["sub"]].id 
            private_ip_address_allocation   = "Static" 
            private_ip_address              = each.value["v6_IP"]
            primary                         = false  
            private_ip_address_version      = "IPv6" 
          }
    }
*/

/*
    dynamic "ip_configuration" {
        for_each = !contains( [ "MGMT", "HA" ], each.key ) ? [1] : []
          content {
            name                            = "${var.prefix}_float_${each.key}_v4" 
            subnet_id                       = azurerm_subnet.this[each.value["sub"]].id 
            private_ip_address_allocation   = "Static" 
            private_ip_address              = var.fw_floating_interfaces[each.key].v4_IP 
            primary                         = false  
            private_ip_address_version      = "IPv4" 
          }
    }

    dynamic "ip_configuration" {
        for_each = !contains( [ "MGMT", "HA" ], each.key ) ? [1] : []
          content {
            name                            = "${var.prefix}_float_${each.key}_v6" 
            subnet_id                       = azurerm_subnet.this[each.value["sub"]].id 
            private_ip_address_allocation   = "Static" 
            private_ip_address              = var.fw_floating_interfaces[each.key].v6_IP 
            primary                         = false  
            private_ip_address_version      = "IPv6" 
          }
    }
*/
    
}


/*
###################################################################################
#
#                            Associate NSG to fxp0 Interfaces
#
###################################################################################

resource "azurerm_network_interface_security_group_association" "fxp0" {
  network_interface_id      = azurerm_network_interface.fw1_int["fxp0"].id
  network_security_group_id = azurerm_network_security_group.fxp0_nsg.id
}

*/

#
#---------------------------------------------------------
# Create FW1 VM
#-------------------------------------------------------------
#




resource "azurerm_linux_virtual_machine" "fw1" {
  name                              = replace("${var.prefix}-fw1","_", "-")
  resource_group_name               = azurerm_resource_group.fw_rsg.name
  location                          = var.az_reg
  size                              = var.fw_vm_size
  admin_username                    = var.aName
  admin_password                    = var.aPass
  disable_password_authentication   = false
#  custom_data                       = var.fw1-config
  secure_boot_enabled               = false
  vtpm_enabled                      = false
  encryption_at_host_enabled        = false
  tags                              = var.tags 
  availability_set_id               = azurerm_availability_set.this.id
#  platform_fault_domain             = "-1"   # requires scale sets

  network_interface_ids             = [ 
    azurerm_network_interface.fw1_int["MGMT"].id,
    azurerm_network_interface.fw1_int["EXT"].id,
    azurerm_network_interface.fw1_int["Inside"].id,
    azurerm_network_interface.fw1_int["HA"].id,
  ]

  source_image_reference  {
    publisher = var.fw_publisher
    offer     = var.fw_offer
    sku       = var.fw_os_sku
    version   = var.fw_version
  }

  os_disk {
    caching                 = "ReadWrite"
    storage_account_type    = "Premium_LRS" 
    name                    = "${var.prefix}_fw1_OsDisk"
  #  disk_size_gb            = "56"   
  }

  plan {
        name        = var.fw_os_sku  
        product     = var.fw_offer
        publisher   = var.fw_publisher
  }

  boot_diagnostics {
        storage_account_uri = azurerm_storage_account.fw1.primary_blob_endpoint
  }

  lifecycle {
      ignore_changes = [ custom_data ]
    }
  
}

#
#---------------------------------------------------------
# Create FW2 Interfaces
#-------------------------------------------------------------
#

resource "azurerm_network_interface" "fw2_int" {
  for_each = var.fw2_interfaces
    name                              = "${var.prefix}_fw2_${each.key}"
    location                          = var.az_reg
    resource_group_name               = azurerm_resource_group.fw_rsg.name
    ip_forwarding_enabled             = true
    accelerated_networking_enabled    = true
    tags                              = var.tags 

    ip_configuration {
        name                            = "${var.prefix}_fw2_${each.key}_v4"
        subnet_id                       = azurerm_subnet.this[each.value["sub"]].id
        private_ip_address_allocation   = "Static"
        private_ip_address              = each.value["v4_IP"]
        primary                         = true
        private_ip_address_version      = "IPv4"
    }

    ip_configuration {
        name                            = "${var.prefix}_fw2_${each.key}_v6"
        subnet_id                       = azurerm_subnet.this[each.value["sub"]].id
        private_ip_address_allocation   = "Static"
        private_ip_address_version      = "IPv6"
        private_ip_address              = each.value["v6_IP"]
    }

/*
    dynamic "ip_configuration" {
        for_each = contains( [ "MGMT", "HA" ], each.key ) ? [1] : []
          content {
            name                            =  "${var.prefix}_fw2_${each.key}_v6"
            subnet_id                       = azurerm_subnet.this[each.value["sub"]].id 
            private_ip_address_allocation   = "Static" 
            private_ip_address              = each.value["v6_IP"]
            primary                         = false  
            private_ip_address_version      = "IPv6" 
          }
    }
*/
/*

*/
}



#
#---------------------------------------------------------
# Create FW2 VM
#-------------------------------------------------------------
#


resource "azurerm_linux_virtual_machine" "fw2" {
  name                              = replace("${var.prefix}-fw2","_", "-")
  resource_group_name               = azurerm_resource_group.fw_rsg.name
  location                          = var.az_reg
  size                              = var.fw_vm_size
  admin_username                    = var.aName
  admin_password                    = var.aPass
  disable_password_authentication   = false
#  custom_data                       = var.fw2-config
  secure_boot_enabled               = false
  vtpm_enabled                      = false
  encryption_at_host_enabled        = false
  tags                              = var.tags 
  availability_set_id               = azurerm_availability_set.this.id
#  platform_fault_domain             = "-1"   # requires scale sets

  network_interface_ids             = [ 
    azurerm_network_interface.fw2_int["MGMT"].id,
    azurerm_network_interface.fw2_int["EXT"].id,
    azurerm_network_interface.fw2_int["Inside"].id,
    azurerm_network_interface.fw2_int["HA"].id,

  ]

  source_image_reference  {
    publisher = var.fw_publisher
    offer     = var.fw_offer
    sku       = var.fw_os_sku
    version   = var.fw_version
  }

  os_disk {
    caching                 = "ReadWrite"
    storage_account_type    = "Premium_LRS" 
    name                    = "${var.prefix}_fw2_OsDisk"
  #  disk_size_gb            = "56"   
  }

  plan {
        name        = var.fw_os_sku  
        product     = var.fw_offer
        publisher   = var.fw_publisher
  }

  boot_diagnostics {
        storage_account_uri = azurerm_storage_account.fw2.primary_blob_endpoint
  }

  lifecycle {
      ignore_changes = [ custom_data ]
    }
  
}






#
#---------------------------------------------------------
# Create Load balancers
#-------------------------------------------------------------
#



#--------------------------------------------------------------------------------
# LB IPv4

resource "azurerm_lb" "fw-v4" {
  for_each = var.fw_floating_interfaces
    name                = "${var.prefix}_${each.key}_LB-v4"
    location            = var.az_reg
    resource_group_name = azurerm_resource_group.fw_rsg.name
    sku                 = "Standard"
    sku_tier            = "Regional"

    frontend_ip_configuration {
      name                          = "${var.prefix}_${each.key}_FE_IPv4"
      subnet_id                     = azurerm_subnet.this["${var.prefix}_${each.key}"].id
      private_ip_address            = var.fw_floating_interfaces[each.key].v4_IP 
      private_ip_address_allocation = "Static"
      private_ip_address_version    = "IPv4"
    }

    tags                = var.tags

}

#--------------------------------------------------------------------------------
# v4 pool and backends

resource "azurerm_lb_backend_address_pool" "pool-v4" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v4[each.key].id
    name                = "${var.prefix}_${each.key}_BE_Pool-v4"
#    virtual_network_id  = azurerm_virtual_network.this.id
}

resource "azurerm_network_interface_backend_address_pool_association" "fw1-v4" {
  for_each = var.fw_floating_interfaces
    network_interface_id    = azurerm_network_interface.fw1_int[each.key].id
    ip_configuration_name   = "${var.prefix}_fw1_${each.key}_v4"
    backend_address_pool_id = azurerm_lb_backend_address_pool.pool-v4[each.key].id
}

resource "azurerm_network_interface_backend_address_pool_association" "fw2-v4" {
  for_each = var.fw_floating_interfaces
    network_interface_id    = azurerm_network_interface.fw2_int[each.key].id
    ip_configuration_name   = "${var.prefix}_fw2_${each.key}_v4"
    backend_address_pool_id = azurerm_lb_backend_address_pool.pool-v4[each.key].id
}

#--------------------------------------------------------------------------------
# LB v4 rule

resource "azurerm_lb_rule" "rule-v4" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id                 = azurerm_lb.fw-v4[each.key].id
    name                            = "${var.prefix}_${each.key}_v4_rule"
    protocol                        = "All"
    frontend_port                   = "0"
    backend_port                    = "0"
    frontend_ip_configuration_name  = "${var.prefix}_${each.key}_FE_IPv4"
    backend_address_pool_ids        = [ azurerm_lb_backend_address_pool.pool-v4[each.key].id ]
    idle_timeout_in_minutes         = local.lb_idle_timeout
    tcp_reset_enabled               = local.tcp_reset_enabled
    probe_id                        = azurerm_lb_probe.fw-v4[each.key].id
}

#--------------------------------------------------------------------------------
# LB probe v4

resource "azurerm_lb_probe" "fw-v4" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v4[each.key].id
    name                = "${var.prefix}_${each.key}_probe_v4"
    protocol            = local.lb_probe_protocol
    port                = local.lb_probe_port
    interval_in_seconds = local.lb_probe_interval
    number_of_probes    = local.lb_probe_count
    
}

#--------------------------------------------------------------------------------
#--------------------------------------------------------------------------------
# LB v6 

resource "azurerm_lb" "fw-v6" {
  for_each = var.fw_floating_interfaces
    name                = "${var.prefix}_${each.key}_LB-v6"
    location            = var.az_reg
    resource_group_name = azurerm_resource_group.fw_rsg.name
    sku                 = "Standard"
    sku_tier            = "Regional"

    frontend_ip_configuration {
      name                          = "${var.prefix}_${each.key}_FE_IPv6"
      subnet_id                     = azurerm_subnet.this["${var.prefix}_${each.key}"].id
      private_ip_address            = var.fw_floating_interfaces[each.key].v6_IP 
      private_ip_address_allocation = "Static"
      private_ip_address_version    = "IPv6"
    }

    tags                = var.tags

}

#--------------------------------------------------------------------------------
# LB v6 pool and backends

resource "azurerm_lb_backend_address_pool" "pool-v6" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v6[each.key].id
    name                = "${var.prefix}_${each.key}_BE_Pool-v6"
#    virtual_network_id  = azurerm_virtual_network.this.id
}

resource "azurerm_network_interface_backend_address_pool_association" "fw1-v6" {
  for_each = var.fw_floating_interfaces
    network_interface_id    = azurerm_network_interface.fw1_int[each.key].id
    ip_configuration_name   = "${var.prefix}_fw1_${each.key}_v6"
    backend_address_pool_id = azurerm_lb_backend_address_pool.pool-v6[each.key].id
}

resource "azurerm_network_interface_backend_address_pool_association" "fw2-v6" {
  for_each = var.fw_floating_interfaces
    network_interface_id    = azurerm_network_interface.fw2_int[each.key].id
    ip_configuration_name   = "${var.prefix}_fw2_${each.key}_v6"
    backend_address_pool_id = azurerm_lb_backend_address_pool.pool-v6[each.key].id
}

#--------------------------------------------------------------------------------
# LB v6 rule

resource "azurerm_lb_rule" "rule-v6" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id                 = azurerm_lb.fw-v6[each.key].id
    name                            = "${var.prefix}_${each.key}_v6_rule"
    protocol                        = "All"
    frontend_port                   = "0"
    backend_port                    = "0"
    frontend_ip_configuration_name  = "${var.prefix}_${each.key}_FE_IPv6"
    backend_address_pool_ids        = [ azurerm_lb_backend_address_pool.pool-v6[each.key].id ]
    idle_timeout_in_minutes         = local.lb_idle_timeout
    tcp_reset_enabled               = local.tcp_reset_enabled
    probe_id                        = azurerm_lb_probe.fw-v6[each.key].id
}

#--------------------------------------------------------------------------------
# LB probe

resource "azurerm_lb_probe" "fw-v6" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v6[each.key].id
    name                = "${var.prefix}_${each.key}_probe_v6"
    protocol            = local.lb_probe_protocol
    port                = local.lb_probe_port
    interval_in_seconds = local.lb_probe_interval
    number_of_probes    = local.lb_probe_count
    
}











/*

resource "azurerm_lb" "fw-v6" {
  for_each = var.fw_floating_interfaces
    name                = "${var.prefix}_${each.key}_LB-v6"
    location            = var.az_reg
    resource_group_name = azurerm_resource_group.fw_rsg.name
    sku                 = "Standard"
    sku_tier            = "Regional"

    frontend_ip_configuration {
      name                          = "${var.prefix}_${each.key}_FE_IPv6"
      subnet_id                     = azurerm_subnet.this["${var.prefix}_${each.key}"].id
      private_ip_address            = var.fw_floating_interfaces[each.key].v6_IP 
      private_ip_address_allocation = "Static"
      private_ip_address_version    = "IPv6"
    }

    tags                = var.tags

}

#--------------------------------------------------------------------------------
# LB v6 pool and backends

resource "azurerm_lb_backend_address_pool" "pool-v6-fw1" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v6[each.key].id
    name                = "${var.prefix}_${each.key}_BE_Pool-v6-fw1"
    synchronous_mode    = "Manual"
    virtual_network_id  = azurerm_virtual_network.this.id
}

resource "azurerm_lb_backend_address_pool" "pool-v6-fw2" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v6[each.key].id
    name                = "${var.prefix}_${each.key}_BE_Pool-v6-fw2"
    synchronous_mode    = "Manual"
    virtual_network_id  = azurerm_virtual_network.this.id
}

resource "azurerm_lb_backend_address_pool_address" "fw1-v6" {
  for_each = var.fw_floating_interfaces
    name                                = "${var.prefix}_fw1_${each.key}_v6"
    ip_address                          = var.fw1_interfaces[each.key].v6_IP
    backend_address_pool_id             = azurerm_lb_backend_address_pool.pool-v6-fw1[each.key].id
#    virtual_network_id                  = azurerm_virtual_network.this.id

}

resource "azurerm_lb_backend_address_pool_address" "fw2-v6" {
  for_each = var.fw_floating_interfaces
    name                                = "${var.prefix}_fw2_${each.key}_v6"
    ip_address                          = var.fw2_interfaces[each.key].v6_IP
    backend_address_pool_id             = azurerm_lb_backend_address_pool.pool-v6-fw2[each.key].id
#    virtual_network_id                  = azurerm_virtual_network.this.id

}

#--------------------------------------------------------------------------------
# LB v6 rule

resource "azurerm_lb_rule" "rule-v6" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id                 = azurerm_lb.fw-v6[each.key].id
    name                            = "${var.prefix}_${each.key}_v6_rule"
    protocol                        = "All"
    frontend_port                   = "0"
    backend_port                    = "0"
    frontend_ip_configuration_name  = "${var.prefix}_${each.key}_FE_IPv6"
    backend_address_pool_ids        = [ azurerm_lb_backend_address_pool.pool-v6-fw1[each.key].id, azurerm_lb_backend_address_pool.pool-v6-fw2[each.key].id, ]
    idle_timeout_in_minutes         = local.lb_idle_timeout
    tcp_reset_enabled               = local.tcp_reset_enabled
    probe_id                        = azurerm_lb_probe.fw-v6[each.key].id
}

#--------------------------------------------------------------------------------
# LB probe v6

resource "azurerm_lb_probe" "fw-v6" {
  for_each = var.fw_floating_interfaces
    loadbalancer_id     = azurerm_lb.fw-v6[each.key].id
    name                = "${var.prefix}_${each.key}_probe_v6"
    protocol            = local.lb_probe_protocol
    port                = local.lb_probe_port
    interval_in_seconds = local.lb_probe_interval
    number_of_probes    = local.lb_probe_count
    
}


*/
