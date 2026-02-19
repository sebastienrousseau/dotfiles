packer {
  required_version = ">= 1.9.0"
}

source "null" "example" {
  communicator = "none"
}

build {
  sources = ["source.null.example"]

  provisioner "shell" {
    inline = ["echo 'Packer template: __PROJECT_NAME__'"]
  }
}
