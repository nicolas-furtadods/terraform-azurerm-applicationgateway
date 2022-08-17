resource "azurerm_user_assigned_identity" "id-agw" {
  name                = "id-${local.naming}-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_key_vault_access_policy" "userAssigned-agw" {
  key_vault_id = var.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.id-agw.principal_id

  certificate_permissions = [
    "Get",
    "List"
  ]

  secret_permissions = [
    "Get"
  ]

}



resource "azurerm_web_application_firewall_policy" "waf" {
  name                = "waf-${local.naming}-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

resource "azurerm_public_ip" "ip" {
  name                = "pip-${local.naming}-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_application_gateway" "agw" {
  depends_on = [
    azurerm_web_application_firewall_policy.waf,
    azurerm_public_ip.ip,
    azurerm_key_vault_access_policy.userAssigned-agw
  ]
  name                = "agw-${local.naming}-001"
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_http2        = true
  tags                = var.tags

  sku {
    name = var.sku_name
    tier = var.sku_tier
  }

  autoscale_configuration {
    min_capacity = var.capacity_min
    max_capacity = var.capacity_max
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.id-agw.id]
  }

  # ---------------- Gateway IP Configuration
  gateway_ip_configuration {
    name      = "cfg-agw-${local.naming}-001"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "${local.frontend_ip_configuration_name}-public"
    public_ip_address_id = azurerm_public_ip.ip.id
  }

  dynamic "frontend_ip_configuration" {
    for_each = {
      for k, v in local.frontend_ip_configuration : k => v if var.gateway_type == "Private"
    }
    iterator = agw
    content {
      name                          = "${local.frontend_ip_configuration_name}-private"
      subnet_id                     = agw.value.subnet_id
      private_ip_address_allocation = agw.value.private_ip_address_allocation
    }
  }

  frontend_port {
    name = "${local.frontend_port_name}-80"
    port = 80
  }

  frontend_port {
    name = "${local.frontend_port_name}-443"
    port = 443
  }

  # ---------------- Load balancing Configuration
  dynamic "backend_address_pool" {
    for_each = {
      for k, v in var.backend_settings : k => v if v.backend_address_pool != null
    }
    iterator = lb
    content {
      name         = "${lb.value.name}${local.backend_address_pool_name_suffix}"
      fqdns        = lb.value.backend_address_pool.fqdns
      ip_addresses = lb.value.backend_address_pool.ip_addresses
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate
    iterator = lb
    content {
      name                = lb.value.name
      key_vault_secret_id = lb.value.key_vault_secret_id
    }
  }

  ssl_policy {
    policy_type = var.ssl_policy.policy_type
    policy_name = var.ssl_policy.policy_name
  }

  dynamic "backend_http_settings" {
    for_each = {
      for k, v in var.backend_settings : k => v if v.backend_http_settings != null
    }
    iterator = lb
    content {
      name                                = "${lb.value.name}${local.http_setting_name_suffix}"
      cookie_based_affinity               = lb.value.backend_http_settings.cookie_based_affinity
      port                                = lb.value.backend_http_settings.port
      protocol                            = lb.value.backend_http_settings.protocol
      request_timeout                     = lb.value.backend_http_settings.request_timeout
      pick_host_name_from_backend_address = lb.value.backend_http_settings.pick_host_name_from_backend_address
      probe_name                          = "${lb.value.name}${local.probe_name_suffix}"
    }
  }

  dynamic "probe" {
    for_each = {
      for k, v in var.backend_settings : k => v if v.probe != null
    }
    iterator = lb
    content {
      name                                      = "${lb.value.name}${local.probe_name_suffix}"
      interval                                  = lb.value.probe.interval
      path                                      = lb.value.probe.path
      protocol                                  = lb.value.probe.protocol
      timeout                                   = lb.value.probe.timeout
      unhealthy_threshold                       = lb.value.probe.unhealthy_threshold
      pick_host_name_from_backend_http_settings = lb.value.probe.pick_host_name_from_backend_http_settings
    }
  }


  dynamic "http_listener" {
    for_each = var.load_balancing_settings
    iterator = lb
    content {
      name                           = "${lb.value.name}${local.http_listener_name_suffix}"
      frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-${lower(var.gateway_type)}"
      frontend_port_name             = "${local.frontend_port_name}-80"
      protocol                       = "Http"
      host_name                      = lb.value.http_listener.host_name_http
    }
  }

  dynamic "http_listener" {
    for_each = var.load_balancing_settings
    iterator = lb
    content {
      name                           = "${lb.value.name}${local.https_listener_name_suffix}"
      frontend_ip_configuration_name = "${local.frontend_ip_configuration_name}-${lower(var.gateway_type)}"
      frontend_port_name             = "${local.frontend_port_name}-443"
      protocol                       = "Https"
      host_name                      = lb.value.http_listener.host_name_https
      ssl_certificate_name           = lb.value.http_listener.ssl_certificate_name == null ? var.default_ssl_certificate_name : lb.value.http_listener.ssl_certificate_name
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.load_balancing_settings
    iterator = lb
    content {
      name                 = "${lb.value.name}${local.redirect_configuration_name_suffix}"
      redirect_type        = "Permanent"
      include_path         = true
      include_query_string = true
      target_listener_name = "${lb.value.name}${local.https_listener_name_suffix}"
    }
  }

  # ----------- Request Routing Rule HTTPS - Basic
  dynamic "request_routing_rule" {
    for_each = {
      for k, v in var.load_balancing_settings : k => v if v.rule.rule_type == "Basic"
    }
    iterator = lb
    content {
      name                       = "${lb.value.name}${local.https_request_routing_rule_name_suffix}"
      rule_type                  = lb.value.rule.rule_type
      http_listener_name         = "${lb.value.name}${local.https_listener_name_suffix}"
      backend_address_pool_name  = "${lb.value.rule.backend_target_name}${local.backend_address_pool_name_suffix}"
      backend_http_settings_name = "${lb.value.rule.backend_target_settings_name}${local.http_setting_name_suffix}"
      priority                   = lb.value.rule.priority
    }
  }


  # ----------- Request Routing Rule HTTPS - Path-based
  dynamic "url_path_map" {
    for_each = {
      for k, v in var.load_balancing_settings : k => v if v.rule.rule_type == "PathBasedRouting"
    }
    iterator = lb
    content {
      name                               = "${lb.value.name}${local.path_based_suffix}"
      default_backend_address_pool_name  = "${lb.value.url_path_map.default_backend_address_pool_name}${local.backend_address_pool_name_suffix}"
      default_backend_http_settings_name = "${lb.value.url_path_map.default_backend_http_settings_name}${local.http_setting_name_suffix}"
      dynamic "path_rule" {
        for_each = lb.value.url_path_map.path_rules
        iterator = ph
        content {
          name                       = "${lb.value.name}${local.path_rule_suffix}"
          paths                      = ph.value.paths
          backend_address_pool_name  = "${ph.value.backend_address_pool_name}${local.backend_address_pool_name_suffix}"
          backend_http_settings_name = "${ph.value.backend_http_settings_name}${local.http_setting_name_suffix}"
        }
      }
    }
  }

  dynamic "request_routing_rule" {
    for_each = {
      for k, v in var.load_balancing_settings : k => v if v.rule.rule_type == "PathBasedRouting"
    }
    iterator = lb
    content {
      name                       = "${lb.value.name}${local.https_request_routing_rule_name_suffix}"
      rule_type                  = lb.value.rule.rule_type
      http_listener_name         = "${lb.value.name}${local.https_listener_name_suffix}"
      #backend_address_pool_name  = "${lb.value.rule.backend_target_name}${local.backend_address_pool_name_suffix}"
      #backend_http_settings_name = "${lb.value.rule.backend_target_settings_name}${local.http_setting_name_suffix}"
      priority                   = lb.value.rule.priority
      url_path_map_name          = "${lb.value.name}${local.path_based_suffix}"
    }
  }

  # ----------- Request Routing Rule HTTP - Basic
  dynamic "request_routing_rule" {
    for_each = {
      for k, v in var.load_balancing_settings : k => v if v.rule.rule_type == "Basic"
    }
    iterator = lb
    content {
      name                        = "${lb.value.name}${local.http_request_routing_rule_name_suffix}"
      rule_type                   = lb.value.rule.rule_type
      http_listener_name          = "${lb.value.name}${local.http_listener_name_suffix}"
      redirect_configuration_name = "${lb.value.name}${local.redirect_configuration_name_suffix}"
      priority                    = (lb.value.rule.priority + 1)
    }
  }

  force_firewall_policy_association = var.sku_name == "WAF_v2" ? true : false
  firewall_policy_id                = var.sku_name == "WAF_v2" ? azurerm_web_application_firewall_policy.waf.id : null
}


resource "azurerm_monitor_diagnostic_setting" "appgw-diag" {
  name                       = "diag-${azurerm_application_gateway.agw.name}"
  target_resource_id         = azurerm_application_gateway.agw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "log" {
    for_each = local.diag_appgw_logs
    content {
      category = log.value

      retention_policy {
        enabled = false
      }
    }

  }
  metric {
    category = "AllMetrics"
    retention_policy {
      enabled = false
    }
  }
}
