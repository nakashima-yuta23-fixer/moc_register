################################
# 個別システム
################################

# マネジメント
## リソースグループ
resource "azurerm_resource_group" "spoke" {
  name     = format("%s%s%s%s", var.environment_code, var.customer_code, "spoke", var.primary_location_code)
  location = var.primary_location
  tags     = {}
}

# 仮想ネットワーク
## Vnet
# Vnetが他社によって払い出される場合はdataで読み込む方式に切り替える必要がある。
resource "azurerm_virtual_network" "spoke" {
  name                = format("%s%s%s%s", var.environment_code, var.customer_code, "spoke", var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  address_space       = ["192.168.0.0/20"]

  lifecycle {
    ignore_changes = [tags]
  }
}

## Subnet
locals {
  subnets = {
    gateway = {
      address_prefix                    = ["192.168.0.0/24"]
      private_endpoint_network_policies = "Disabled"
      delegations = {
        # "application-gateway-delegation" = {
        gateway = {
          service_delegation = {
            name    = "Microsoft.Network/applicationGateways"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
        }
      }
    }
    ingress_privatelink = {
      address_prefix                    = ["192.168.1.0/24"]
      private_endpoint_network_policies = "Disabled" # 要確認
    }
    workload = {
      address_prefix                    = ["192.168.2.0/24"]
      private_endpoint_network_policies = "Disabled"
      delegations = {
        delegation = {
          # "app-service-delegation" = {
          service_delegation = {
            name    = "Microsoft.Web/serverFarms"
            actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
          }
        }
      }
    }
    egress_privatelink = {
      address_prefix                    = ["192.168.3.0/24"]
      private_endpoint_network_policies = "Disabled" # 要確認
    }
  }
}

resource "azurerm_subnet" "spoke" {
  for_each = local.subnets

  # terraform style guideに従った記法で変数を定義しています。
  # ラベル定義のために'-'は'_'で記載していたため必要です。
  name                 = replace(each.key, "_", "-")
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke.name

  address_prefixes                  = each.value.address_prefix
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  # TODO: プライベートエンドポイントを配置するサブネットには下記を設定する必要があるかどうか確認する。
  # enforce_private_link_service_network_policies = true

  # サブネットに委任の定義がある場合は動的に委任を追加します。
  # 委任のオブジェクトが空のmapでない場合に作成されます。
  dynamic "delegation" {
    for_each = try(each.value.delegations, {})

    content {
      name = delegation.key
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

## NSG
locals {
  nsgs = {
    gateway = {
      name = format("%s%s%s%s", var.environment_code, var.customer_code, "gateway", var.primary_location_code)
    }
    ingress_privatelink = {
      name = format("%s%s%s%s", var.environment_code, var.customer_code, "ingressprivatelink", var.primary_location_code)
    }
    workload = {
      name = format("%s%s%s%s", var.environment_code, var.customer_code, "workload", var.primary_location_code)
    }
    egress_privatelink = {
      name = format("%s%s%s%s", var.environment_code, var.customer_code, "egressprivatelink", var.primary_location_code)
    }
  }
}

resource "azurerm_network_security_group" "spoke" {
  for_each = local.nsgs

  name                = each.value.name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name

  lifecycle {
    ignore_changes = [tags]
  }
}

### NSGルール
resource "azurerm_network_security_rule" "gateway" {
  name                        = "AllowGatewayManager"
  resource_group_name         = azurerm_resource_group.spoke.name
  network_security_group_name = azurerm_network_security_group.spoke["gateway"].name

  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  destination_address_prefix = "*"
  destination_port_range     = "*"
  source_address_prefix      = "GatewayManager"
  source_port_range          = "*"
}

## SubnetとNSGの関連付け
locals {
  subnet_nsg_association = {
    gateway = {
      subnet_id = azurerm_subnet.spoke["gateway"].id
      nsg_id    = azurerm_network_security_group.spoke["gateway"].id
    }
    ingress_privatelink = {
      subnet_id = azurerm_subnet.spoke["ingress_privatelink"].id
      nsg_id    = azurerm_network_security_group.spoke["ingress_privatelink"].id
    }
    workload = {
      subnet_id = azurerm_subnet.spoke["workload"].id
      nsg_id    = azurerm_network_security_group.spoke["workload"].id
    }
    egress_privatelink = {
      subnet_id = azurerm_subnet.spoke["egress_privatelink"].id
      nsg_id    = azurerm_network_security_group.spoke["egress_privatelink"].id
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke" {
  for_each = local.subnet_nsg_association

  subnet_id                 = each.value.subnet_id
  network_security_group_id = each.value.nsg_id
}

# ストレージ
# DBやログファイル格納用のBLOB Storage

# ワークロード
## App Service Plan
resource "azurerm_service_plan" "workload" {
  name                         = format("%s%s%s%s", var.environment_code, var.customer_code, "app", var.primary_location_code)
  resource_group_name          = azurerm_resource_group.spoke.name
  location                     = azurerm_resource_group.spoke.location
  os_type                      = "Linux"
  sku_name                     = "S1"
  worker_count                 = 1
  maximum_elastic_worker_count = 1
  zone_balancing_enabled       = false

  lifecycle {
    ignore_changes = [tags]
  }
}

# App Service (Web)
resource "azurerm_app_service" "web" {
  name                = format("%s%s%s%s", var.environment_code, var.customer_code, "web", var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  app_service_plan_id = azurerm_service_plan.workload.id

  https_only = true
  site_config {
    always_on = true
    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php",
      "hostingstart.html",
    ]
    http2_enabled             = false
    linux_fx_version          = "NODE|24-lts"
    number_of_workers         = 1
    use_32_bit_worker_process = true
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# App Service (Travel Expenses)
resource "azurerm_app_service" "travel_expenses" {
  name                = format("%s%s%s%s", var.environment_code, var.customer_code, "travel", var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location
  app_service_plan_id = azurerm_service_plan.workload.id

  https_only = true
  site_config {
    always_on = true
    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php",
      "hostingstart.html",
    ]
    http2_enabled             = false
    linux_fx_version          = "PYTHON|3.14"
    number_of_workers         = 1
    use_32_bit_worker_process = true
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# 接続
## プライベートDNSゾーン - App Service
resource "azurerm_private_dns_zone" "app_service" {
  # TODO: 下記のソースをMS Learnから探し、リンクを貼る
  name                = "privatelink.azurewebsites.net" # Azure によって名前は定められている。
  resource_group_name = azurerm_resource_group.spoke.name

  lifecycle {
    ignore_changes = [tags]
  }
}

## 仮想ネットワークリンク - App Service の プライベートDNSゾーン
resource "azurerm_private_dns_zone_virtual_network_link" "app_service" {
  name                  = "appservice-link"
  resource_group_name   = azurerm_resource_group.spoke.name
  private_dns_zone_name = azurerm_private_dns_zone.app_service.name
  virtual_network_id    = azurerm_virtual_network.spoke.id
}

## プライベートエンドポイント - To App Service Web
resource "azurerm_private_endpoint" "app_service_web" {
  name                = format("%s%s%s%s", var.environment_code, var.customer_code, "web", var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location

  custom_network_interface_name = format("%s%s%s%s-nic", var.environment_code, var.customer_code, "web", var.primary_location_code)
  subnet_id                     = azurerm_subnet.spoke["ingress_privatelink"].id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.app_service.id]
  }

  private_service_connection {
    is_manual_connection              = false
    name                              = "privateserviceconnection-app-service-web"
    private_connection_resource_alias = null
    private_connection_resource_id    = azurerm_app_service.web.id
    request_message                   = null
    subresource_names                 = ["sites"]
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

## プライベートエンドポイント - To Travel
resource "azurerm_private_endpoint" "app_service_travel" {
  name                = format("%s%s%s%s", var.environment_code, var.customer_code, "travel", var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location

  custom_network_interface_name = format("%s%s%s%s-nic", var.environment_code, var.customer_code, "travel", var.primary_location_code)
  subnet_id                     = azurerm_subnet.spoke["egress_privatelink"].id

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.app_service.id]
  }

  private_service_connection {
    is_manual_connection              = false
    name                              = "privateserviceconnection-app-service-travel"
    private_connection_resource_alias = null
    private_connection_resource_id    = azurerm_app_service.travel_expenses.id
    request_message                   = null
    subresource_names                 = ["sites"]
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# ゲートウェイ
## WAF
resource "azurerm_web_application_firewall_policy" "gateway" {
  name                = format("%s%s%s", var.environment_code, var.customer_code, var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  policy_settings {
    enabled                                   = true
    file_upload_enforcement                   = true
    file_upload_limit_in_mb                   = 100
    js_challenge_cookie_expiration_in_minutes = 30
    max_request_body_size_in_kb               = 128
    mode                                      = "Detection"
    request_body_check                        = true
    request_body_enforcement                  = true
    request_body_inspect_limit_in_kb          = 128
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

## Application Gateway
resource "azurerm_application_gateway" "gateway" {
  name                = format("%s%s%s", var.environment_code, var.customer_code, var.primary_location_code)
  resource_group_name = azurerm_resource_group.spoke.name
  location            = azurerm_resource_group.spoke.location

  enable_http2                      = false
  fips_enabled                      = false
  firewall_policy_id                = azurerm_web_application_firewall_policy.gateway.id
  force_firewall_policy_association = false
  zones                             = ["1", "2", "3"]

  backend_address_pool {
    fqdns        = [azurerm_app_service.web.default_site_hostname]
    ip_addresses = []
    name         = "pool-workload"
  }

  backend_http_settings {
    affinity_cookie_name                 = null
    cookie_based_affinity                = "Disabled"
    dedicated_backend_connection_enabled = false
    host_name                            = azurerm_app_service.web.default_site_hostname
    name                                 = "backend-workload"
    path                                 = null
    pick_host_name_from_backend_address  = false
    port                                 = 443
    probe_name                           = null
    protocol                             = "Https"
    request_timeout                      = 20
    trusted_root_certificate_names       = []
  }

  frontend_ip_configuration {
    name                            = "appGwPrivateFrontendIpIPv4"
    private_ip_address              = "192.168.0.4"
    private_ip_address_allocation   = "Static"
    private_link_configuration_name = null
    public_ip_address_id            = null
    subnet_id                       = azurerm_subnet.spoke["gateway"].id
  }

  frontend_port {
    name = "port_80"
    port = 80
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.spoke["gateway"].id
  }

  http_listener {
    firewall_policy_id             = null
    frontend_ip_configuration_name = "appGwPrivateFrontendIpIPv4"
    frontend_port_name             = "port_80"
    host_name                      = null
    host_names                     = []
    name                           = "http-listener"
    protocol                       = "Http"
    require_sni                    = false
    ssl_certificate_name           = null
    ssl_profile_name               = null
  }

  request_routing_rule {
    backend_address_pool_name   = "pool-workload"
    backend_http_settings_name  = "backend-workload"
    http_listener_name          = "http-listener"
    name                        = "rule-workload"
    priority                    = 1
    redirect_configuration_name = null
    rewrite_rule_set_name       = null
    rule_type                   = "Basic"
    url_path_map_name           = null
  }

  sku {
    capacity = 1
    name     = "WAF_v2"
    tier     = "WAF_v2"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# others (仮置き)
