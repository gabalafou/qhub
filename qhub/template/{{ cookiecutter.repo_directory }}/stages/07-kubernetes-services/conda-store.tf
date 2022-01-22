# ======================= VARIABLES ======================
variable "conda-store-environments" {
  description = "Conda-Store managed environments"
  default = {}
}


variable "conda-store-image" {
  description = "Conda-store image"
  type = object({
    name = string
    tag  = string
  })
  default = {
    name = "{{ cookiecutter.default_images.conda_store.split(':')[0] }}"
    tag  = "{{ cookiecutter.default_images.conda_store.split(':')[1] }}"
  }
}


# ====================== RESOURCES =======================
module "kubernetes-conda-store-server" {
  source = "./modules/kubernetes/services/conda-store"

  name              = "qhub"
  namespace         = var.environment

  external-url = var.endpoint
  realm_id     = var.realm_id

  nfs_capacity      = "{{ cookiecutter.storage.conda_store }}"
  node-group        = local.node_groups.general
  conda-store-image = var.conda-store-image
  environments      = {
    for filename, environment in var.conda-store-environments:
    filename => yamlencode(environment)
  }
}

module "conda-store-nfs-mount" {
  source = "./modules/kubernetes/nfs-mount"

  name         = "conda-store"
  namespace    = var.environment
  nfs_capacity = "{{ cookiecutter.storage.conda_store }}"
  nfs_endpoint = module.kubernetes-conda-store-server.endpoint_ip

  depends_on = [
    module.kubernetes-conda-store-server
  ]
}