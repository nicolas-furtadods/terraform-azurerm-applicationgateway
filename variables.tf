##########################################################################
# 0. Global Configuration
##########################################################################
variable "application" {
  description = "Name of the application for which the resources are created (agw,corenet etc.)"
  type        = string
}

variable "technical_zone" {
  description = "Enter a 2-digits technical zone which will be used by resources (in,ex,cm,sh)"
  type        = string

  validation {
    condition = (
      length(var.technical_zone) > 0 && length(var.technical_zone) <= 2
    )
    error_message = "The technical zone must be a 2-digits string."
  }
}
variable "environment" {
  description = "Enter the 3-digits environment which will be used by resources (hpr,sbx,prd,hyb)"
  type        = string

  validation {
    condition = (
      length(var.environment) > 0 && length(var.environment) <= 3
    )
    error_message = "The environment must be a 3-digits string."
  }
}

variable "location" {
  description = "Enter the region for which to create the resources."
}

variable "tags" {
  description = "Tags to apply to your resources"
  type        = map(string)
  default = {}
}

variable "resource_group_name" {
  description = "Name of the resource group where resources will be created"
  type        = string
}

##########################################################################
# 1. Virtual Network Configuration
##########################################################################

variable "subnet_id" {
  description = "A subnet ID needed to create the gateway resource"
  type        = string
}

variable "transversal_key_vault_subscription_id" {
  description = "Enter the subscription id containing transversal resources like Key Vault"
  type = string
}

variable "key_vault_id" {
  description = "Provide a key vault ID to store information and get certificates."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID to for diagnostics"
  type        = string
}


##########################################################################
# 2. Application Gateway
##########################################################################

variable "gateway_type" {
  description = "(Optional) The type of Application Gateway you want to use, valid values include: Public, Private"
  type        = string
  default     = "Public"
  validation {
    condition = (
      var.gateway_type == "Public" || var.gateway_type == "Private"
    )
    error_message = "Valid values include: Public, Private."
  }
}

variable "private_ip_address" {
  description = "(Optional) The Private IP Address to use for the Application Gateway. This is mandatory for gateway type `Private`"
  type        = string
  default     = null
}

variable "capacity_min" {
  description = "The Capacity of the SKU to use for this Application Gateway. When using a V1 SKU this value must be between 1 and 32, and 1 to 125 for a V2 SKU."
  type        = number
  default = 1
}

variable "capacity_max" {
  description = "The Capacity of the SKU to use for this Application Gateway. When using a V1 SKU this value must be between 1 and 32, and 1 to 125 for a V2 SKU."
  type        = number
  default = 1
}

variable "sku_name" {
  description = "The Name of the SKU to use for this Application Gateway. Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2."
  type        = string
}

variable "sku_tier" {
  description = "The Name of the SKU to use for this Application Gateway. Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2."
  type        = string
}


variable "ssl_policy" {
  description = "A SSL Profile block to define."
  type = object({
    policy_type = string
    policy_name = string
  })
  default = {
    policy_name = "AppGwSslPolicy20220101"
    policy_type = "Predefined"
  }
}

variable "backend_settings" {
  description = "Backend settings"
  type = map(object({
    name = string
    backend_address_pool = object({
      fqdns        = list(string)
      ip_addresses = list(string)
    })
    backend_http_settings = object({
      cookie_based_affinity               = string
      port                                = number
      protocol                            = string
      request_timeout                     = number
      pick_host_name_from_backend_address = bool

    })
    probe = object({
      interval                                  = number
      path                                      = string
      protocol                                  = string
      timeout                                   = number
      unhealthy_threshold                       = number
      pick_host_name_from_backend_http_settings = bool

    })
  }))
  default = {
    "terraform-default" = {
      name = "terraform-create-nottouse"
      backend_address_pool = {
        fqdns        = ["mysite1.azurewebsites.net"]
        ip_addresses = null
      }
      backend_http_settings = {
        cookie_based_affinity               = "Disabled"
        pick_host_name_from_backend_address = true
        port                                = 443
        protocol                            = "Https"
        request_timeout                     = 30
      }
      probe = {
        interval                                  = 30
        path                                      = "/"
        pick_host_name_from_backend_http_settings = true
        protocol                                  = "Https"
        timeout                                   = 30
        unhealthy_threshold                       = 3
      }
    }
  }
}

variable "ssl_certificate" {
  description = "SSL certificates settings"
  type = map(object({
    name                = string
    key_vault_secret_id = string
  }))
}

variable "default_ssl_certificate_name" {
  description = "Default SSL certificate to use"
  type        = string
}
variable "load_balancing_settings" {
  description = "Load Balancing settings "
  type = map(object({
    name = string
    http_listener = object({
      host_name_http       = string
      host_name_https      = string
      ssl_certificate_name = string
    })
    rule = object({
      backend_target_name          = string
      backend_target_settings_name = string
      rule_type                    = string
      priority                     = number
    })
    url_path_map = object({
      default_backend_address_pool_name  = string
      default_backend_http_settings_name = string
      path_rules = map(object({
        paths                      = list(string)
        backend_address_pool_name  = string
        backend_http_settings_name = string
      }))
    })
  }))
  default = {
    "terraform-default" = {
      name = "terraform-create-nottouse"
      http_listener = {
        host_name_http       = "appgw-test"
        host_name_https      = "appgw-test"
        ssl_certificate_name = null
      }
      rule = {
        backend_target_name          = "terraform-create-nottouse"
        backend_target_settings_name = "terraform-create-nottouse"
        rule_type                    = "Basic"
        priority                     = 10
      }
      url_path_map = null
    }
  }
}
