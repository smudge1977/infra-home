variable "proxmox_endpoint" {
  description = "Proxmox API origin, including :8006 for direct access or the reverse-proxy HTTPS port."
  type        = string
  default     = "https://prox01.keithmarston.me.uk/"

  validation {
    condition     = can(regex("^https://[^/]+/?$", var.proxmox_endpoint))
    error_message = "Use an HTTPS origin, optionally with a port, not an /api2/json path."
  }
}

variable "template_vm_id" {
  description = "Existing Ubuntu 26.04 cloud-init template ID on prox01. Never import this template into this state."
  type        = number

  validation {
    condition     = var.template_vm_id >= 100 && floor(var.template_vm_id) == var.template_vm_id
    error_message = "Provide an existing template's integer VM ID (at least 100)."
  }
}

variable "ssh_public_key" {
  description = "Public SSH key for ubuntu; never supply a private key."
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+( .*)?$", trimspace(var.ssh_public_key)))
    error_message = "Supply one OpenSSH public key, not a private key or file path."
  }
}

variable "vm_id" {
  description = "Unused cluster-wide VM ID reserved for this disposable trial."
  type        = number
  default     = 4001

  validation {
    condition     = var.vm_id >= 100 && floor(var.vm_id) == var.vm_id
    error_message = "The trial VM ID must be an integer of at least 100."
  }
}

variable "disk_size_gb" {
  description = "Root disk size in GiB; must be at least the source template's disk size (clones cannot shrink)."
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size_gb >= 20 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "Choose a whole number of GiB, at least 20 and no smaller than the template disk."
  }
}