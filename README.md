# Azure Application Gateway
[![Changelog](https://img.shields.io/badge/changelog-release-green.svg)](CHANGELOG.md) [![Notice](https://img.shields.io/badge/notice-copyright-yellow.svg)](NOTICE) [![Apache V2 License](https://img.shields.io/badge/license-Apache%20V2-orange.svg)](LICENSE)

This Terraform feature creates a standalone [Azure Application Gateway](https://docs.microsoft.com/en-us/azure/application-gateway/overview), allowing you to quickly deploy the resource and dependencies. Access to key vault will also be configured when provided with ID.

## Version compatibility

| Module version | Terraform version | AzureRM version |
|----------------|-------------------|-----------------|
| >= 1.x.x       | 1.1.0             | >= 3.12         |

## Usage

### Global Module Configuration
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "<your_rg_name>"
  location = "francecentral"
  tags = {
    "Application"        = "azuretesting",
  }
}

module "applicationgateway" {
  source = "./terraform-azurerm-applicationgateway" # Your path may be different.
  
##########################################################################
# 0. Global Configuration
##########################################################################

  # Mandatory Parameters
  application         = "azuretesting"
  environment         = "poc"
  location            = "francecentral"
  resource_group_name = azurerm_resource_group.core_rg.name
  technical_zone      = "cm"
  tags = {
    "Application"        = "azuretesting",
  }
  
##########################################################################
# 1. Virtual Network Configuration
##########################################################################

  subnet_id                  = "/subscriptions/{Subscription ID}/resourceGroups/MyResourceGroup/providers/Microsoft.Network/virtualNetworks/MyNet/subnets/MySubnet"
  key_vault_id               = "/subscriptions/{Subscription ID}/resourceGroups/MyResourceGroup/providers/Microsoft.KeyVault/vaults/MyKeyVault"
  log_analytics_workspace_id = "/subscriptions/{Subscription ID}/resourceGroups/MyResourceGroup/providers/Microsoft.OperationalInsights/workspaces/MyWorkspaceName"

##########################################################################
# 2. Application Gateway
##########################################################################

  sku_name = "Standard_v2"
  sku_tier = "Standard_v2"

  ssl_certificate = {
    "wildcard" = {
      key_vault_secret_id = "https://yourkeyvault.vault.azure.net/secrets/wildcard"
      name                = "wildcard"
    }
  }
  
  #For HTTPS
  default_ssl_certificate_name = "wildcard"

  # Optional. Default to Public
  gateway_type = "Public"

  # Optional. Default to 1
  capacity_min               = 1

  # Optional. Default to 1
  capacity_max               = 2

  backend_settings = {
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

  load_balancing_settings = {
    "terraform-default" = {
      name = "terraform-create-nottouse"
      http_listener = {
        host_name_http       = "appgw-test.recyclage.veolia.fr"
        host_name_https      = "appgw-test.recyclage.veolia.fr"
        ssl_certificate_name = null
      }
      rule = {
        backend_target_name          = "terraform-create-nottouse"
        backend_target_settings_name = "terraform-create-nottouse"
        priority                     = 10
        rule_type                    = "Basic"
      }
      #Optionnal
      url_path_map = {
        default_backend_address_pool_name  = "terraform-create-nottouse"
        default_backend_http_settings_name = "terraform-create-nottouse"
        path_rules = {
          "external" : {
            paths                      = ["/external*"]
            backend_address_pool_name  = "terraform-create-nottouse"
            backend_http_settings_name = "terraform-create-nottouse"
          }
        }
      }
    }
  }
}
```

## Arguments Reference

The following arguments are supported:
  - `application` - (Required) Name of the application for which the virtual network is created (agw,corenet etc.).
  - `default_ssl_certificate_name` - (Required) Default SSL certificate to use for HTTPS connection.
  - `environment` - (Required) A 3-digits environment which will be used by resources (hpr,sbx,prd,hyb).
  - `key_vault_id` - (Required) Provide a key vault ID to store information and get certificates.
  - `load_balancing_settings` - (Required) A load balancing map as defined below.
  - `location` - (Required) The region for which to create the resources.
  - `log_analytics_workspace_id` - (Required) Log Analytics Workspace ID to for diagnostics.
  - `resource_group_name` - (Required) Name of the resource group where resources will be created.
  - `sku_name` - (Required) The Name of the SKU to use for this Application Gateway. Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2.
  - `sku_tier` - (Required) The Name of the SKU to use for this Application Gateway. Possible values are Standard_Small, Standard_Medium, Standard_Large, Standard_v2, WAF_Medium, WAF_Large, and WAF_v2.
  - `ssl_certificate` - (Required) A `ssl_certificate` map as defined below.
  - `subnet_id` - (Required) A subnet ID needed to create the gateway resource.
  - `technical_zone` - (Required) A 2-digits technical zone which will be used by resources (in,ex,cm,sh).

##
  - `backend_settings` - (Optional)  A `backend_settings` map as defined below.
  - `capacity_min` - (Optional) The Capacity of the SKU to use for this Application Gateway. When using a V1 SKU this value must be between 1 and 32, and 1 to 125 for a V2 SKU.
  - `capacity_max` - (Optional) The Capacity of the SKU to use for this Application Gateway. When using a V1 SKU this value must be between 1 and 32, and 1 to 125 for a V2 SKU.
  - `gateway_type` - (Optional) The type of Application Gateway you want to use, valid values include: Public, Private.
  - `ssl_policy` - (Optional)  A `ssl_policy` object as defined below.
  - `tags` - (Optional) A key-value map of string.
  
##
A `backend_settings` map support the following:
  - `name` - (Required) Name used by all resources on the backend : Address Pool, HTTP Settings, Probe.
  - `backend_address_pool` - (Required) A `backend_address_pool` object as defined below.
  - `backend_http_settings` - (Required) A `backend_http_settings` object as defined below.
  - `probe` - (Required) A `probe` object as defined below.

##
A `backend_address_pool` object support the following:
  - `fqdns` - (Optional) List of FQDNS.
  - `ip_addresses` - (Optional) List of ip_addresses.

##
A `backend_http_settings` object support the following:
  - `cookie_based_affinity` - (Required) Is Cookie-Based Affinity enabled? Possible values are `Enabled` and `Disabled`.
  - `pick_host_name_from_backend_address` - (Required) Whether host header should be picked from the host name of the backend server.
  - `port` - (Required) The port which should be used for this Backend HTTP Settings Collection.
  - `protocol` - (Required) The Protocol which should be used. Possible values are `Http` and `Https`.
  - `request_timeout` - (Optional) The request timeout in seconds, which must be between 1 and 86400 seconds. Defaults to 30.

##
A `http_listener` object support the following:
  - `host_name_http` - (Required) The Hostname which should be used for this HTTP Listener.
  - `host_name_https` - (Required) The Hostname which should be used for this HTTPs Listener.
  - `ssl_certificate_name` - (Optional) The name of the associated SSL Certificate which should be used for this HTTP Listener.

##
A `load_balancing_settings` map support the following:
  - `name` - (Required) Name used by all resources on the backend : HTTP Listener, Rules, Path-Baseed Mapping.
  - `http_listener` - (Required) A `http_listener` object as defined below.
  - `rule` - (Required) A `rule` object as defined below.
  - `url_path_map` - (Optional) A `url_path_map` object as defined below.

##
A `path_rules` map support the following:
  - `paths` - (Required) A list of Paths used in this Path Rule.
  - `backend_address_pool_name` - (Required) The Name of the Backend Address Pool to use for this Path Rule.
  - `backend_http_settings_name` - (Required) The Name of the Backend HTTP Settings Collection to use for this Path Rule.

##
A `probe` object support the following:
  - `interval` - (Required) The Interval between two consecutive probes in seconds. Possible values range from 1 second to a maximum of 86,400 seconds.
  - `path` - (Required) The Path used for this Probe.
  - `pick_host_name_from_backend_http_settings` - (Required) Whether the host header should be picked from the backend HTTP settings. Defaults to false.
  - `protocol` - (Required) The Protocol which should be used. Possible values are `Http` and `Https`.
  - `timeout` - (Required) The Timeout used for this Probe, which indicates when a probe becomes unhealthy. Possible values range from 1 second to a maximum of 86,400 seconds.
  - `timeout` - (Required) The Unhealthy Threshold for this Probe, which indicates the amount of retries which should be attempted before a node is deemed unhealthy. Possible values are from 1 to 20.

##
A `rule` object support the following:
  - `backend_target_name` - (Required) The Name of the Backend Address Pool which should be used for this Routing Rule.
  - `backend_target_settings_name` - (Required) The Name of the Backend HTTP Settings Collection which should be used for this Routing Rule. 
  - `rule_type` - (Required) The Type of Routing that should be used for this Rule. Possible values are `Basic` and `PathBasedRouting`.
  - `priority` - (Required) Rule evaluation order can be dictated by specifying an integer value from 1 to 20000 with 1 being the highest priority and 20000 being the lowest priority.

##
A `ssl_certificate` map support the following:
  - `name` - (Required) The certificate Name, as will be shown on the Application Gateway.
  - `key_vault_secret_id` - (Required) The Key Vault Secret ID of the certificate.


##
A `ssl_policy` object support the following:
  - `policy_name` - (Required) The Name of the Policy e.g `AppGwSslPolicy20170401S`. Required if `policy_type` is set to `Predefined`. Possible values can change over time and are published here https://docs.microsoft.com/azure/application-gateway/application-gateway-ssl-policy-overview. Not compatible with `disabled_protocols`.
  - `policy_type` - (Required) The Type of the Policy. Possible values are `Predefined` and `Custom`.

##
A `url_path_map` map support the following:
  - `default_backend_address_pool_name` - (Required) The Name of the Default Backend Address Pool which should be used for this URL Path Map.
  - `default_backend_http_settings_name` - (Required) The Name of the Default Backend HTTP Settings Collection which should be used for this URL Path Map
  - `path_rules` - (Required) A `path_rules` map as defined below.



## Attribute Reference

The following Attributes are exported:
  - `application_gateway` - A `application_gateway` object as defined below.
  - `web_application_firewall_policy_id` - ID of the WAF Policy created.
  
##
A `application_gateway` block exports the following:
  - `backend_address_pool` - A list of `backend_address_pool` blocks as defined below.
  - `backend_http_settings` - A list of `backend_http_settings` blocks as defined below.
  - `frontend_ip_configuration` - A list of `frontend_ip_configuration` blocks as defined below.
  - `frontend_port` - A list of `frontend_port` blocks as defined below.
  - `gateway_ip_configuration` - A list of `gateway_ip_configuration` blocks as defined below.
  - `enable_http2` - Is HTTP2 enabled on the application gateway resource? Defaults to `false`.
  - `http_listener` - A list of `http_listener` blocks as defined below.
  - `id` - The ID of the Application Gateway.
  - `managed_identity_id` - The User Assigned Principal ID created for the application gateway.
  - `private_endpoint_connection` - A list of `private_endpoint_connection` blocks as defined below.
  - `private_link_configuration` - A list of `private_link_configuration` blocks as defined below.
  - `probe` - A `probe` block as defined below.
  - `public_ip_address_id` - Public IP ID created.
  - `request_routing_rule` - A list of `request_routing_rule` blocks as defined below.
  - `ssl_certificate` - A list of `ssl_certificate` blocks as defined below.
  - `url_path_map` - A list of `url_path_map` blocks as defined below.
  - `custom_error_configuration` - A list of `custom_error_configuration` blocks as defined below.
  - `redirect_configuration` - A list of `redirect_configuration` blocks as defined below.
##
A `backend_address_pool` object exports the following:
  - `id` - The ID of the Backend Address Pool.

##
A `backend_http_settings` object exports the following:
  - `id` - The ID of the Backend HTTP Settings Configuration.
  - `probe_id` - The ID of the associated Probe.

##
A `frontend_ip_configuration` block exports the following:
  - `id` - The ID of the Frontend IP Configuration.
  - `private_link_configuration_id` - The ID of the associated private link configuration.

##
A `frontend_port` block exports the following:
  - `id` - The ID of the Frontend Port.

##
A `gateway_ip_configuration` block exports the following:
  - `id` - The ID of the Gateway IP Configuration.

##
A `http_listener` block exports the following:
  - `id` - The ID of the HTTP Listener.
  - `frontend_ip_configuration_id` - The ID of the associated Frontend Configuration.
  - `frontend_port_id` - The ID of the associated Frontend Port.
  - `ssl_certificate_id` - The ID of the associated SSL Certificate.
  - `ssl_profile_id` - The ID of the associated SSL Certificate.

##
A `path_rule` block exports the following:
  - `id` - The ID of the Path Rule.
  - `backend_address_pool_id` - The ID of the Backend Address Pool used in this Path Rule.
  - `backend_http_settings_id` - The ID of the Backend HTTP Settings Collection used in this Path Rule.
  - `redirect_configuration_id` - The ID of the Redirect Configuration used in this Path Rule.
  - `rewrite_rule_set_id` - The ID of the Rewrite Rule Set used in this Path Rule.

##
A `private_endpoint_connection` block exports the following:
  - `name` - The name of the private endpoint connection.
  - `id` - The ID of the private endpoint connection.

##
A `private_link_configuration` block exports the following:
  - `id` - The ID of the private link configuration.

##
A `probe` block exports the following:
  - `id` - The ID of the Probe.

##
A `request_routing_rule` block exports the following:
  - `id` - The ID of the Request Routing Rule.
  - `http_listener_id` - The ID of the associated HTTP Listener.
  - `backend_address_pool_id` - The ID of the associated Backend Address Pool.
  - `backend_http_settings_id` - The ID of the associated Backend HTTP Settings Configuration.
  - `redirect_configuration_id` - The ID of the associated Redirect Configuration.
  - `rewrite_rule_set_id` - The ID of the associated Rewrite Rule Set.
  - `url_path_map_id` - The ID of the associated URL Path Map.

##
A `ssl_certificate` block exports the following:
  - `id` - The ID of the SSL Certificate.

  - `public_cert_data` - The Public Certificate Data associated with the SSL Certificate.

##
A `url_path_map` block exports the following:
  - `id` - The ID of the URL Path Map.
  - `default_backend_address_pool_id` - The ID of the Default Backend Address Pool.
  - `default_backend_http_settings_id` - The ID of the Default Backend HTTP Settings Collection.
  - `default_redirect_configuration_id` - The ID of the Default Redirect Configuration.
  - `path_rule` - A list of path_rule blocks as defined above.

##
A `custom_error_configuration` block exports the following:
  - `id` - The ID of the Custom Error Configuration.

##
A `redirect_configuration` block exports the following:
  - `id` - The ID of the Redirect Configuration.

## References
Please check the following references for best practices.
* [Terraform Best Practices](https://www.terraform-best-practices.com/)
* [Azure Policy as Code with Terraform Part 1](https://purple.telstra.com/blog/azure-policy-as-code-with-terraform-part-1)