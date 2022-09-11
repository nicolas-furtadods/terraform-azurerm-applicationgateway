output "application_gateway" {
    value = {
        id = azurerm_application_gateway.agw.id
        backend_address_pool = azurerm_application_gateway.agw.backend_address_pool
        backend_http_settings = azurerm_application_gateway.agw.backend_http_settings
        frontend_ip_configuration = azurerm_application_gateway.agw.frontend_ip_configuration
        frontend_port = azurerm_application_gateway.agw.frontend_port
        gateway_ip_configuration = azurerm_application_gateway.agw.gateway_ip_configuration
        enable_http2 = azurerm_application_gateway.agw.enable_http2 
        http_listener = azurerm_application_gateway.agw.http_listener 
        managed_identity_id = azurerm_user_assigned_identity.id-agw.principal_id
        private_endpoint_connection = azurerm_application_gateway.agw.private_endpoint_connection 
        private_link_configuration = azurerm_application_gateway.agw.private_link_configuration
        probe = azurerm_application_gateway.agw.probe 
        public_ip_address_id = azurerm_public_ip.ip.id
        request_routing_rule = azurerm_application_gateway.agw.request_routing_rule 
        ssl_certificate = azurerm_application_gateway.agw.ssl_certificate 
        url_path_map = azurerm_application_gateway.agw.url_path_map 
        custom_error_configuration = azurerm_application_gateway.agw.custom_error_configuration
        redirect_configuration = azurerm_application_gateway.agw.redirect_configuration 
    }
    description = "Application Gateway ouputs"
}

output "web_application_firewall_policy_id" {
    value = azurerm_web_application_firewall_policy.waf.id
}