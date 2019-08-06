provider "azurerm" {
}

resource "azurerm_resource_group" "asp_net" {
  name     = "asp-net"
  location = "Central US"
}

resource "azurerm_app_service_plan" "asp_net_plan" {
  name                = "asp-net-plan"
  location            = "Central US"
  resource_group_name = "${azurerm_resource_group.asp_net.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "tomcat-app-autoscaleSetting"
  resource_group_name = "${azurerm_resource_group.asp_net.name}"
  location            = "Central US"
  target_resource_id  = "${azurerm_app_service_plan.asp_net_plan.id}"

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name         = "CpuPercentage"
		metric_resource_id  = "${azurerm_app_service_plan.asp_net_plan.id}"
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT5M"
        time_aggregation    = "Average"
        operator            = "GreaterThan"
        threshold           = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name         = "CpuPercentage"
		metric_resource_id  = "${azurerm_app_service_plan.asp_net_plan.id}"
        time_grain          = "PT1M"
        statistic           = "Average"
        time_window         = "PT5M"
        time_aggregation    = "Average"
        operator            = "LessThan"
        threshold           = 20
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

resource "azurerm_app_service" "asp_net_app" {
  name                = "asp-net-app-1"
  location            = "Central US"
  resource_group_name = "${azurerm_resource_group.asp_net.name}"
  app_service_plan_id = "${azurerm_app_service_plan.asp_net_plan.id}"

  site_config {
    dotnet_framework_version = "v4.0"
  }
  
  app_settings = {
     "ASPNETCORE_ENVIRONMENT" = "Production"
  }
}

# terraform apply -var="<login>" -var="<password>"

resource "azurerm_sql_server" "asp_net_sql_server" {
  name                         = "asp-net-sql-server"
  resource_group_name          = "${azurerm_resource_group.asp_net.name}"
  location                     = "Central US"
  administrator_login          = var.login
  administrator_login_password = var.password
  version                      = "12.0"
}

resource "azurerm_sql_database" "asp_net_sql_database" {
  name                             = "asp-net-sql-database"
  resource_group_name              = "${azurerm_resource_group.asp_net.name}"
  location                         = "Central US"
  server_name                      = "${azurerm_sql_server.asp_net_sql_server.name}"
  edition                          = "Basic"
  requested_service_objective_name = "Basic"
}

resource "azurerm_sql_firewall_rule" "asp_net_sql_rule" {
  name                = "allow-azure-services"
  resource_group_name = "${azurerm_resource_group.asp_net.name}"
  server_name         = "${azurerm_sql_server.asp_net_sql_server.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}