#
#---------------------------------------------------------
# Create Hub RSG
#-------------------------------------------------------------
#

resource "azurerm_resource_group" "hub" {
    name     = "${var.prefix}_rsg"
    location = var.az_reg
    tags     = var.tags 
}

#
#---------------------------------------------------------
# Create hub vNet
#-------------------------------------------------------------
#
resource "azurerm_virtual_network" "this" {
    name                            = "${var.prefix}_vNet"
    address_space                   = values(merge(var.hub_cidrs_v4, var.hub_cidrs_v6))
    location                        = var.az_reg
    resource_group_name             = azurerm_resource_group.hub.name
    dns_servers                     = var.dns_servers
    tags                            = var.tags
    private_endpoint_vnet_policies  = "Basic"
    bgp_community                   = var.er_bgp_primary_com
}

#
#---------------------------------------------------------
# Route Tables
#-------------------------------------------------------------
#

resource "azurerm_route_table" "this" {
    for_each = var.hub_subnets
        name                            = "${each.key}_UDR"
        location                        = var.az_reg
        resource_group_name             = azurerm_resource_group.hub.name
        bgp_route_propagation_enabled   = each.key == "GatewaySubnet" || strcontains( each.key, "Bastion" )  || strcontains( each.key, "EXT") ? true : false
        tags                            = var.tags
}


#
#---------------------------------------------------------
# Create NSG for Bastion Subnet
#-------------------------------------------------------------
#

resource "azurerm_network_security_group" "bastion" {
  name                = "${var.prefix}_Bastion_NSG"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}



resource "azurerm_network_security_rule" "bastion_rule" {
  for_each = var.mgmt_nsg
    name                          = each.key
    priority                      = each.value["priority"]
    direction                     = each.value["direction"]
    access                        = each.value["access"]
    protocol                      = each.value["protocol"]
    source_port_range             = "*"
    destination_port_range        = each.value["destination_port_range"]
    destination_port_ranges       = each.value["destination_port_ranges"]
    source_address_prefix         = each.value["source_address_prefix"]
    source_address_prefixes       = each.value["source_address_prefixes"]
    destination_address_prefix    = each.value["destination_address_prefix"]
    destination_address_prefixes  = each.value["destination_address_prefixes"]
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.bastion.name
}




#
#---------------------------------------------------------
# Create NSG for FW Interface Subnets
#-------------------------------------------------------------
#



resource "azurerm_network_security_group" "fw-subs" {
  name                = "${var.prefix}_fw_NSG"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}


resource "azurerm_network_security_rule" "DENY-TCP-53-IPv6-IN" {
    name                          = "DENY-TCP-53-IPv6-IN"
    priority                      = 106
    direction                     = "Inbound"
    access                        = "Deny"
    protocol                      = "Tcp"
    source_port_range             = "*"
    destination_port_range        = "53"
    source_address_prefix         = "*"
    destination_address_prefix    = var.hub_cidrs_v6["Primary_v6"]
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.fw-subs.name
}



resource "azurerm_network_security_rule" "fw-any-in" {
    name                          = "Any-IN"
    priority                      = 120
    direction                     = "Inbound"
    access                        = "Allow"
    protocol                      = "*"
    source_port_range             = "*"
    destination_port_range        = "*"
    source_address_prefix         = "*"
    destination_address_prefix    = "*"
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.fw-subs.name
}

resource "azurerm_network_security_rule" "fw-any-icmp-in" {
    name                          = "Any-ICMP-IN"
    priority                      = 110
    direction                     = "Inbound"
    access                        = "Allow"
    protocol                      = "Icmp"
    source_port_range             = "*"
    destination_port_range        = "*"
    source_address_prefix         = "*"
    destination_address_prefix    = "*"
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.fw-subs.name
}

resource "azurerm_network_security_rule" "fw-any-out" {
    name                          = "Any-Out"
    priority                      = 100
    direction                     = "Outbound"
    access                        = "Allow"
    protocol                      = "*"
    source_port_range             = "*"
    destination_port_range        = "*"
    source_address_prefix         = "*"
    destination_address_prefix    = "*"
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.fw-subs.name
}

resource "azurerm_network_security_rule" "fw-any-icmp-out" {
    name                          = "Any-ICMP-Out"
    priority                      = 110
    direction                     = "Outbound"
    access                        = "Allow"
    protocol                      = "Icmp"
    source_port_range             = "*"
    destination_port_range        = "*"
    source_address_prefix         = "*"
    destination_address_prefix    = "*"
    resource_group_name           = azurerm_resource_group.hub.name
    network_security_group_name   = azurerm_network_security_group.fw-subs.name
}




#
#---------------------------------------------------------
# Create Routes for Express_RT_GW pointed to FW floating external IP
#-------------------------------------------------------------
#



resource "azurerm_route" "local_v4" {
  for_each = {
    for i in var.local_routes_v4 : replace( i ,"/", "-" ) => i
  }
    name                    = each.key
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = each.value
    next_hop_type           = "VirtualAppliance" 
    next_hop_in_ip_address  = var.fw_floating_interfaces["EXT"].v4_IP
}

resource "azurerm_route" "local_v6" {
  for_each = {
    for i in var.local_routes_v6 : replace(replace( i ,"/", "-" ),":", "." )=> i
  }
    name                    = each.key
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = each.value
    next_hop_type           = "VirtualAppliance" 
    next_hop_in_ip_address  = var.fw_floating_interfaces["EXT"].v6_IP
}


resource "azurerm_route" "ext_v4" {
    name                    = "${var.prefix}_EXT_v4"
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = cidrsubnet( var.hub_cidrs_v4["Primary_v4"] , 5, 2 )   
    next_hop_type           = "VnetLocal" 
}

resource "azurerm_route" "ext_v6" {
    name                    = "${var.prefix}_EXT_v6"
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = cidrsubnet( var.hub_cidrs_v6["Primary_v6"] , 4, 2 )   
    next_hop_type           = "VnetLocal" 
}



resource "azurerm_route" "bastion_v4" {
    name                    = "${var.prefix}_Bastion_v4"
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = var.hub_bastion_v4
#    address_prefix          = cidrsubnet( var.hub_cidrs_v4["Primary_v4"] , 4, 4 )   
    next_hop_type           = "VnetLocal" 
}

resource "azurerm_route" "bastion_v6" {
    name                    = "${var.prefix}_Bastion_v6"
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "GatewaySubnet_UDR"
    address_prefix          = var.hub_bastion_v6
 #   address_prefix          = cidrsubnet( var.hub_cidrs_v6["Primary_v6"] , 4, 7 )   
    next_hop_type           = "VnetLocal" 
}



#################  ROUTES to different regional hubs ################

resource "azurerm_route" "peer_hub_v4" {
  for_each = { 
    for key, value in var.peer_routes_v4 : key => value 
    if !contains([key], "null" )
  } 

    name                    = each.key
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "${var.prefix}_Peer_UDR"
    address_prefix          = replace( each.key ,"-", "/" )
    next_hop_type           = "VirtualAppliance" 
    next_hop_in_ip_address  = each.value
}

resource "azurerm_route" "peer_hub_v6" {
  for_each = { 
    for key, value in var.peer_routes_v6 : key => value 
    if !contains([key], "null" )
  } 
    name                    = each.key
    resource_group_name     = azurerm_resource_group.hub.name
    route_table_name        = "${var.prefix}_Peer_UDR"
    address_prefix          = replace(replace( each.key ,"-", "/" ), ".", ":" )
    next_hop_type           = "VirtualAppliance" 
    next_hop_in_ip_address  = each.value
}





#
#---------------------------------------------------------
# Create Subnets
#-------------------------------------------------------------
#

resource "azurerm_subnet" "this" {
  for_each = var.hub_subnets
    name                                          = each.key
    resource_group_name                           = azurerm_resource_group.hub.name
    virtual_network_name                          = azurerm_virtual_network.this.name
    address_prefixes                              = each.value["Subs"] 
    private_endpoint_network_policies             = each.value["priv_endpt"] 
    default_outbound_access_enabled               = each.value["default_outbound_access_enabled"]  
    private_link_service_network_policies_enabled = each.value["priv_link_net_pols"] 


/*
    dynamic "service_endpoint" {
      for_each = {
          for i in each.value["Sub_Svc_Endpoints"] , "null"
      }
        !contains( each.value["Sub_Svc_Endpoints"], "null" ) ? toset(each.value["Sub_Svc_Endpoints"]) : []
      
      content {
        service = each.value
      }
    }
*/

    dynamic "service_endpoint" {
      for_each = !contains( each.value["Sub_Svc_Endpoints"], "null" ) ? toset(each.value["Sub_Svc_Endpoints"]) : []
      
      content {
        service = service_endpoint.value
      }
    }


    dynamic "delegation" {
        for_each = each.value["Sub_Delegation"] ? [1] : [] 
        content {
          name = each.value["Sub_Delegation_Name"]
          service_delegation {
            actions = each.value["Sub_Delegation_Actions"]
            name    = each.value["Sub_Delegation_Actions_Name"]
          }
        }
     }
}

#
#---------------------------------------------------------
# Associate Route Tables to subnets
#-------------------------------------------------------------
#

resource "azurerm_subnet_route_table_association" "this" {
  for_each = var.hub_subnets  
    subnet_id      = azurerm_subnet.this[each.key].id
    route_table_id = azurerm_route_table.this[each.key].id
}



#
#---------------------------------------------------------
# Associate NSG to Bastion Subnet
#-------------------------------------------------------------
#

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.this["${var.prefix}_Bastion"].id
  network_security_group_id = azurerm_network_security_group.bastion.id
}


#
#---------------------------------------------------------
# Associate NSG's to FW interface Subnets
#-------------------------------------------------------------
#

resource "azurerm_subnet_network_security_group_association" "fw-subs" {
  for_each = {
    for key,value in var.hub_subnets : key => value 
    if alltrue( [ !contains([key], "${var.prefix}_Bastion"),  !contains([key], "GatewaySubnet"), ] )
  }
    subnet_id                 = azurerm_subnet.this[each.key].id
    network_security_group_id = azurerm_network_security_group.fw-subs.id
}



#
#---------------------------------------------------------
# Create Express Route Gateway
#-------------------------------------------------------------
#

resource "azurerm_virtual_network_gateway" "this" {
  name                        = "${var.prefix}_ER_GW"
  location                    = var.az_reg
  resource_group_name         = azurerm_resource_group.hub.name
  type                        = "ExpressRoute"
  active_active               = false
  bgp_enabled                 = var.er_bgp_enabled
  sku                         = var.er_gw_sku    #"Standard"
  remote_vnet_traffic_enabled = true 
  virtual_wan_traffic_enabled = true
  tags                        = var.tags

  ip_configuration {
    name                            = "${var.prefix}_ExprRT_GW_v4_IP"
    private_ip_address_allocation   = "Dynamic"
    subnet_id                       = azurerm_subnet.this["GatewaySubnet"].id
  }
}

#
#---------------------------------------------------------
# Attach to Express Route Circuits 
#-------------------------------------------------------------
#

resource "azurerm_virtual_network_gateway_connection" "this" {
    for_each = var.express_routes
        name                		            = "${var.prefix}_${each.key}_EX_RT"
        location                	          = var.az_reg
        resource_group_name                 = azurerm_resource_group.hub.name
        type                                = "ExpressRoute"
        virtual_network_gateway_id          = azurerm_virtual_network_gateway.this.id
        routing_weight                      = each.value["weight"]
        express_route_circuit_id            = each.value["circuit_id"]
        authorization_key				            = each.value["auth_key"]
        express_route_gateway_bypass        = each.value["ergw_bypass"]
        use_policy_based_traffic_selectors  = each.value["pol_based_traffic_selector"]
        tags                                = var.tags
        shared_key                          = each.value["shared_key"]
        private_link_fast_path_enabled      = each.value["prv_link_fast_path_enabled"]
        connection_mode                     = "Default"
}


































