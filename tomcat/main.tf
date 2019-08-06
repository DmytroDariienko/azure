provider "azurerm" {
}

resource "azurerm_resource_group" "tomcat" {
  name     = "tomcat-a"
  location = "West Europe"
}

resource "azurerm_app_service_plan" "tomcat_plans" {
  count               = length(var.plan_names)
  name                = var.plan_names[count.index]
  location            = var.lacations[count.index]
  resource_group_name = "${azurerm_resource_group.tomcat.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  count               = length(var.plan_names)
  name                = "tomcat-app"[count.index]"-autoscaleSetting"
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  location            = var.lacations[count.index]
  target_resource_id  = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 2
      maximum = 1
    }

    rule {
      metric_trigger {
        metric_name         = "CpuPercentage"
		metric_resource_id  = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"
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
		metric_resource_id  = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"
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

resource "azurerm_app_service" "tomcat_apps" {
  count               = length(var.app_names)
  name                = var.app_names[count.index]
  location            = var.lacations[count.index]
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  app_service_plan_id = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"

  site_config {
    java_version           = 11
	java_container         = "Tomcat"
	java_container_version = "9.0"
  }
  
  app_settings = {
     "SCM_TARGET_PATH" = "D:\home\site\wwwroot\webapps\ROOT"
  }
}

resource "azurerm_traffic_manager_profile" "tomcat_trafic_manager" {
  name                = "tomcat-trafic-manager"
  resource_group_name = "${azurerm_resource_group.tomcat.name}"

  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "tomcatapp"
    ttl           = 100
  }

  monitor_config {
    protocol = "https"
    port     = 443
    path     = "/"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_traffic_manager_endpoint" "endpoints" {
  count               = length(var.app_names)
  name                = var.app_names[count.index]
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  profile_name        = "${azurerm_traffic_manager_profile.tomcat_trafic_manager.name}"
  target_resource_id  = "${azurerm_app_service.tomcat_apps[count.index].id}"
  type                = "azureEndpoints"
}