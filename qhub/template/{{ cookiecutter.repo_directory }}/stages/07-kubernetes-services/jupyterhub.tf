variable "cdsdashboards" {
  description = "Enable CDS Dashboards"
  type        = object({
    enabled = bool
    cds_hide_user_named_servers = bool
    cds_hide_user_dashboard_servers = bool
  })
  default     = {
    enabled = true
    cds_hide_user_named_servers = true
    cds_hide_user_dashboard_servers = false
  }
}

variable "jupyterhub-theme" {
  description = "JupyterHub theme"
  type        = map
  default     = {}
}

variable "jupyterhub-image" {
  description = "Jupyterhub user image"
  type = object({
    name = string
    tag  = string
  })
  default = {
    name = "{{ cookiecutter.default_images.jupyterhub.split(':')[0] }}"
    tag  = "{{ cookiecutter.default_images.jupyterhub.split(':')[1] }}"
  }
}

variable "jupyterlab-image" {
  description = "Jupyterlab user image"
  type = object({
    name = string
    tag  = string
  })
  default = {
    name = "{{ cookiecutter.default_images.jupyterlab.split(':')[0] }}"
    tag  = "{{ cookiecutter.default_images.jupyterlab.split(':')[1] }}"
  }
}

variable "jupyterlab-profiles" {
  description = "JupyterHub profiles to expose to user"
  default = []
}


{% if cookiecutter.provider == "aws" -%}
module "jupyterhub-nfs-mount" {
  source = "./modules/kubernetes/nfs-mount"

  name         = "jupyterhub"
  namespace    = var.environment
  nfs_capacity = "{{ cookiecutter.storage.shared_filesystem }}"
  nfs_endpoint = module.efs.credentials.dns_name
}
{% else -%}
module "kubernetes-nfs-server" {
  source = "./modules/kubernetes/nfs-server"

  name         = "nfs-server"
  namespace    = var.environment
  nfs_capacity = "{{ cookiecutter.storage.shared_filesystem }}"
  node-group   = local.node_groups.general
}

module "jupyterhub-nfs-mount" {
  source = "./modules/kubernetes/nfs-mount"

  name         = "jupyterhub"
  namespace    = var.environment
  nfs_capacity = "{{ cookiecutter.storage.shared_filesystem }}"
  nfs_endpoint = module.kubernetes-nfs-server.endpoint_ip

  depends_on = [
    module.kubernetes-nfs-server
  ]
}
{% endif %}


module "jupyterhub" {
  source = "./modules/kubernetes/services/jupyterhub"

  name      = var.name
  namespace = var.environment

  external-url = var.endpoint
  realm_id = var.realm_id

  home-pvc = module.jupyterhub-nfs-mount.persistent_volume_claim.name

  shared-pvc = module.jupyterhub-nfs-mount.persistent_volume_claim.name

  extra-mounts = {
    "/home/conda" = module.conda-store-nfs-mount.persistent_volume_claim
    "etc/dask"    = {
      name = "dask-etc"
      namespace = var.environment
      kind = "configmap"
    }
  }

  services = [
    "dask-gateway"
    {% if cookiecutter.prefect.enabled -%}"prefect"{% endif %}
  ]

  jupyterhub-image = var.jupyterhub-image
  jupyterlab-image = var.jupyterlab-image

  cdsdashboards    = var.cdsdashboards

  theme = var.jupyterhub-theme
  profiles = var.jupyterlab-profiles
}