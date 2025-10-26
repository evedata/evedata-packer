# hcloud.pkr.hcl
packer {
  required_plugins {
    hcloud = {
      version = "v1.7.0"
      source  = "github.com/hetznercloud/hcloud"
    }
  }
}

variable "build_date" {
  type = string
  default = env("BUILD_DATE")
}

variable "build_id" {
  type = string
  default = env("BUILD_ID")
}

variable "build_timestamp" {
  type = string
  default = env("BUILD_TIMESTAMP")
}

variable "talos_schematic_id" {
  type = string
  default = env("TALOS_SCHEMATIC_ID")
}

variable "talos_version" {
  type    = string
  default = "v1.11.0"
}

variable "image_url_arm" {
  type    = string
  default = null
}

variable "image_url_x86" {
  type    = string
  default = null
}

variable "server_location" {
  type    = string
  default = "fsn1"
}

locals {
  image_arm = var.image_url_arm != null ? var.image_url_arm : "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/hcloud-arm64.raw.xz"
  image_x86 = var.image_url_x86 != null ? var.image_url_x86 : "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/hcloud-amd64.raw.xz"

  # Add local variables for inline shell commands
  download_image = "wget --timeout=5 --waitretry=5 --tries=5 --retry-connrefused --inet4-only -O /tmp/talos.raw.xz "

  write_image = <<-EOT
    set -ex
    echo 'Talos image loaded, writing to disk... '
    xz -d -c /tmp/talos.raw.xz | dd of=/dev/sda && sync
    echo 'done.'
  EOT

  clean_up = <<-EOT
    set -ex
    echo "Cleaning-up..."
    rm -rf /etc/ssh/ssh_host_*
  EOT
}

# Source for the Talos ARM image
source "hcloud" "talos-arm" {
  rescue       = "linux64"
  image        = "debian-11"
  location     = "${var.server_location}"
  server_type  = "cax11"
  ssh_username = "root"

  snapshot_name   = "evedata-talos-${var.talos_version}-arm-${var.build_date}"
  snapshot_labels = {
    build_id = var.build_id,
    build_timestamp = var.build_timestamp,
    os      = "talos",
    version = "${var.talos_version}",
    arch    = "arm",
    creator = "evedata-packer"
  }
}

# Source for the Talos x86 image
source "hcloud" "talos-x86" {
  rescue       = "linux64"
  image        = "debian-11"
  location     = "${var.server_location}"
  server_type  = "cx22"
  ssh_username = "root"

  snapshot_name   = "evedata-talos-${var.talos_version}-x86-${var.build_date}"
  snapshot_labels = {
    build_id = var.build_id,
    build_timestamp = var.build_timestamp,
    os      = "talos",
    version = "${var.talos_version}",
    arch    = "x86",
    creator = "evedata-packer"
  }
}

# Build the Talos ARM snapshot
build {
  sources = ["source.hcloud.talos-arm"]

  # Download the Talos ARM image
  provisioner "shell" {
    inline = ["${local.download_image}${local.image_arm}"]
  }

  # Write the Talos ARM image to the disk
  provisioner "shell" {
    inline = [local.write_image]
  }

  # Clean-up
  provisioner "shell" {
    inline = [local.clean_up]
  }
}

# Build the Talos x86 snapshot
build {
  sources = ["source.hcloud.talos-x86"]

  # Download the Talos x86 image
  provisioner "shell" {
    inline = ["${local.download_image}${local.image_x86}"]
  }

  # Write the Talos x86 image to the disk
  provisioner "shell" {
    inline = [local.write_image]
  }

  # Clean-up
  provisioner "shell" {
    inline = [local.clean_up]
  }
}