variable "proxmox_endpoint" {
  description = "prox01 API origin, including :8006 for direct access or the reverse-proxy HTTPS port."
  type        = string
  default     = "https://prox01.keithmarston.me.uk/"

  validation {
    condition     = can(regex("^https://[^/]+/?$", var.proxmox_endpoint))
    error_message = "Use an HTTPS origin, optionally with a port, not an /api2/json path."
  }
}

variable "owner" {
  description = "Owner label for the mandatory owner-* tag."
  type        = string
  default     = "keith"
}

variable "node_name" {
  description = "Proxmox node that hosts dev VMs (prox01)."
  type        = string
  default     = "prox01"
}

variable "datastore_id" {
  description = "prox01 datastore for dev VM disks."
  type        = string
  default     = "ZFS01"
}

variable "bridge" {
  description = "prox01 bridge for dev VM NICs."
  type        = string
  default     = "vmbr0"
}

variable "pool_id" {
  description = "Existing Proxmox resource pool for dev VMs; null for none."
  type        = string
  default     = null
}

variable "vm_id_range" {
  description = "Inclusive VM ID range reserved for dev; unique per host but kept disjoint from sandbox and prod."
  type = object({
    min = number
    max = number
  })
  default = {
    min = 5000
    max = 5099
  }
}

variable "template_vm_id" {
  description = "Existing Ubuntu 26.04 cloud-init template ID on prox01. Never import this template into this state."
  type        = number
}

variable "ssh_public_key" {
  description = "Public SSH key for ubuntu; never supply a private key."
  type        = string
}

variable "protect_vm" {
  description = "Enable Proxmox deletion protection on every VM. Explicitly disable and apply before an approved teardown."
  type        = bool
  default     = true
}

variable "vms" {
  description = "VMs in this environment, keyed by a stable name. The key is part of the Terraform address, so renaming it replaces the VM."
  type = map(object({
    name         = string
    description  = optional(string, "Managed by Terraform.")
    system       = string
    vm_id        = number
    extra_tags   = optional(list(string), [])
    cores        = optional(number, 2)
    memory_mb    = optional(number, 2048)
    disk_size_gb = optional(number, 20)
    linked_clone = optional(bool, false)
    on_boot      = optional(bool, false)
  }))

  default = {}

  validation {
    condition     = length(distinct([for v in values(var.vms) : v.vm_id])) == length(var.vms)
    error_message = "Each VM needs a unique vm_id."
  }
}
