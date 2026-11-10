variable "proxmox_endpoint" {
  description = "HTTPS API origin for prox04; TLS verification remains enabled."
  type        = string

  validation {
    condition     = can(regex("^https://[^/]+/?$", var.proxmox_endpoint))
    error_message = "Use the prox04 HTTPS origin, optionally with a port, not an API path."
  }
}

variable "owner" {
  description = "Owner label used by the shared VM module."
  type        = string
  default     = "infra"
}

variable "datastore_id" {
  description = "Verified prox04 datastore supporting VM disks and cloud-init drives."
  type        = string
}

variable "private_bridge" {
  description = "Verified prox04 bridge attached only to the intended internal network."
  type        = string

  validation {
    condition     = length(trimspace(var.private_bridge)) > 0 && !can(regex("REPLACE", var.private_bridge))
    error_message = "Set an explicitly verified private bridge; replace the example placeholder."
  }
}

variable "private_network_confirmed" {
  description = "Explicit acknowledgement that the selected bridge has no public/WAN ingress."
  type        = bool
  default     = false

  validation {
    condition     = var.private_network_confirmed
    error_message = "Confirm that private_bridge has no public/WAN ingress and is reachable only from the intended internal network before planning or applying."
  }
}

variable "pool_id" {
  description = "Existing prox04 resource pool, if one is required; this root does not create it."
  type        = string
  default     = null
}

variable "linked_clone" {
  description = "Use a Proxmox linked clone; the source template disk must be on datastore_id and retained while this VM exists."
  type        = bool
  default     = false
}

variable "protect_vm" {
  description = "Enable Proxmox deletion protection. Disabled by default for this disposable dev VM; enable only when deliberate retention is required."
  type        = bool
  default     = false
}

variable "disk_size_gb" {
  description = "Root volume size in GiB; must be at least the source template disk size because Proxmox cannot shrink a clone."
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_gb >= 20 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "disk_size_gb must be a whole number of GiB, at least 20 and no smaller than the source template disk."
  }
}

variable "vm_id" {
  description = "Proposed VM ID; confirm it is free on the Proxmox cluster before planning/applying."
  type        = number
  default     = 5101
}

variable "vm_id_range" {
  description = "Candidate range disjoint from documented dev/sandbox ranges; check actual allocations before use."
  type = object({
    min = number
    max = number
  })
  default = {
    min = 5100
    max = 5199
  }
}

variable "template_vm_id" {
  description = "Existing, clean Ubuntu 26.04 cloud-init template ID on prox04."
  type        = number

  validation {
    condition     = var.template_vm_id >= 100 && floor(var.template_vm_id) == var.template_vm_id
    error_message = "Set the numeric ID of the verified Ubuntu 26.04 cloud-init template on prox04."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key for the ubuntu administration account; never provide a private key."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/=]+( .*)?$", trimspace(var.ssh_public_key)))
    error_message = "Supply one OpenSSH public key, not a private key or file path."
  }
}
