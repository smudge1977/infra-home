variable "name" {
  description = "Proxmox VM name."
  type        = string
}

variable "description" {
  description = "Proxmox VM description."
  type        = string
  default     = "Managed by Terraform."
}

variable "node_name" {
  description = "Proxmox node that hosts the VM."
  type        = string
}

variable "datastore_id" {
  description = "Datastore for the root disk, cloud-init drive and full-clone target."
  type        = string
}

variable "bridge" {
  description = "Proxmox bridge for the single virtio NIC."
  type        = string
}

variable "pool_id" {
  description = "Existing Proxmox resource pool to place the VM in; null for none. The pool is not created here."
  type        = string
  default     = null
}

variable "env" {
  description = "Environment label, written to the mandatory env-* tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_.-]*$", var.env))
    error_message = "Use lowercase letters, digits, '-', '_' or '.'; Proxmox tags allow nothing else."
  }
}

variable "system" {
  description = "System or application label, written to the mandatory system-* tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_.-]*$", var.system))
    error_message = "Use lowercase letters, digits, '-', '_' or '.'; Proxmox tags allow nothing else."
  }
}

variable "owner" {
  description = "Owner label, written to the mandatory owner-* tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9_.-]*$", var.owner))
    error_message = "Use lowercase letters, digits, '-', '_' or '.'; Proxmox tags allow nothing else."
  }
}

variable "extra_tags" {
  description = "Additional Proxmox tags beyond terraform and the mandatory env/system/owner tags."
  type        = list(string)
  default     = []
}

variable "vm_id" {
  description = "Unused cluster-wide VM ID, which must fall inside vm_id_range."
  type        = number

  validation {
    condition     = var.vm_id >= 100 && floor(var.vm_id) == var.vm_id
    error_message = "The VM ID must be an integer of at least 100."
  }
}

variable "vm_id_range" {
  description = "Inclusive VM ID range reserved for this environment; guards against crossing into another environment's IDs."
  type = object({
    min = number
    max = number
  })

  validation {
    condition     = var.vm_id_range.min >= 100 && var.vm_id_range.min <= var.vm_id_range.max
    error_message = "vm_id_range needs min >= 100 and min <= max."
  }
}

variable "template_vm_id" {
  description = "Existing cloud-init template ID. Never import this template into this state."
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

variable "cores" {
  description = "vCPU cores."
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "Dedicated memory in MiB."
  type        = number
  default     = 2048
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

variable "linked_clone" {
  description = "Use a linked clone instead of an independent full clone."
  type        = bool
  default     = false
}

variable "protect_vm" {
  description = "Enable Proxmox deletion protection. Explicitly disable and apply before an approved teardown."
  type        = bool
  default     = true
}

variable "on_boot" {
  description = "Start the VM when the Proxmox node boots."
  type        = bool
  default     = false
}
