output "vm_public_ip" {
  description = "The public IP address of the gateway VM."
  value       = azurerm_public_ip.vm_ip.ip_address
}

output "dns_fqdn" {
  description = "The fully qualified domain name for the VM."
  value       = azurerm_dns_a_record.temp.fqdn
}
