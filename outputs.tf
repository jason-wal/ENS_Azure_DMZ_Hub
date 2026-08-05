# Output variables go here

output "vnet_rsg_name" {
    value = azurerm_resource_group.hub.name
}

output "vnet_name" {
    value = azurerm_virtual_network.this.name
}

output "vnet_id" {
    value = azurerm_virtual_network.this.id
}

/*
output "dns_rsg_name" {
    value = azurerm_resource_group.hub-dns.name
}
*/