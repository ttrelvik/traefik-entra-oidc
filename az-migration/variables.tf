variable "location" {
  type        = string
  description = "The Azure region to deploy to."
  default     = "East US"
}

variable "resource_group_name" {
  type        = string
  description = "The resource group to deploy VM and network resources into."
  default     = "rg-swarm-vm"
}

variable "vm_size" {
  type        = string
  description = "The VM size to provision."
  default     = "Standard_B2s"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the virtual machine."
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key."
  default     = "~/.ssh/id_ed25519.pub"
}

variable "ssh_source_address_prefix" {
  type        = string
  description = "Source IP address allowed for inbound SSH traffic."
  default     = "96.231.99.187"
}

variable "dns_zone_name" {
  type        = string
  description = "Name of the existing delegated DNS zone."
  default     = "az.trelvik.net"
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource Group where the DNS zone resides."
  default     = "rgdns"
}

variable "dns_record_name" {
  type        = string
  description = "DNS A record subdomain name."
  default     = "mid"
}
