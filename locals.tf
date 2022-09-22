locals {
  ##########################################################################
  # 0. Global Configuration
  ##########################################################################
  naming               = replace(lower("${var.technical_zone}-${var.environment}-${var.application}"), " ", "")
  naming_noapplication = replace(lower("${var.technical_zone}-${var.environment}"), " ", "")

  ##########################################################################
  # 2. Application Gateway
  ##########################################################################
  frontend_ip_configuration = {
    attributes = {
      private_ip_address_allocation = "Static"
      subnet_id                     = var.subnet_id
      private_ip_address            = var.private_ip_address
    }
  }

  agw_resources_name                     = "terraform-create-nottouse"
  frontend_port_name                     = "feport"
  frontend_ip_configuration_name         = "feip"
  http_setting_name_suffix               = "-be-htst"
  http_listener_name_suffix              = "-In-80"
  https_listener_name_suffix             = "-In-443"
  http_request_routing_rule_name_suffix  = "-rqrt-http"
  https_request_routing_rule_name_suffix = "-rqrt-https"
  redirect_configuration_name_suffix     = "-rdrcfg"
  backend_address_pool_name_suffix       = "-pool"
  probe_name_suffix                      = "-probe"
  path_based_suffix                      = "-urlpb"
  path_rule_suffix                       = "-urlpr"

  diag_appgw_logs = [
    "ApplicationGatewayAccessLog",
    "ApplicationGatewayPerformanceLog",
    "ApplicationGatewayFirewallLog",
  ]
}