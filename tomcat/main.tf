provider "azurerm" {
}

resource "azurerm_resource_group" "tomcat" {
  name     = "tomcat-a"
  location = "West Europe"
}

resource "azurerm_app_service_plan" "tomcat_plans" {
  count               = length(var.plan_names)
  name                = var.plan_names[count.index]
  location            = var.locations[count.index]
  resource_group_name = "${azurerm_resource_group.tomcat.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_monitor_autoscale_setting" "autoscale" {
  count               = length(var.plan_names)
  name                = "${var.app_names[count.index]}-autoscaleSetting"
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  location            = var.locations[count.index]
  target_resource_id  = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"

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
  location            = var.locations[count.index]
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  app_service_plan_id = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"

  site_config {
    java_version           = 11
        java_container         = "Tomcat"
        java_container_version = "9.0"
  }
}

resource "azurerm_app_service_slot" "tomcat_app_slots" {
  count               = length(var.app_names)
  name                = "${var.app_names[count.index]}-slot"
  app_service_name    = "${azurerm_app_service.tomcat_apps[count.index].name}"
  location            = "${azurerm_app_service.tomcat_apps[count.index].location}"
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  app_service_plan_id = "${azurerm_app_service_plan.tomcat_plans[count.index].id}"

  site_config {
    java_version           = 11
        java_container         = "Tomcat"
        java_container_version = "9.0"
  }
}

resource "azurerm_template_deployment" "tomcat_virtual_directory_tamplates" {
  count               = length(var.app_names)
  name                = "${var.app_names[count.index]}-virtual-directory"
  resource_group_name = "${azurerm_resource_group.tomcat.name}"
  deployment_mode     = "Incremental"

  template_body = <<DEPLOY
{
  "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
        "webAppName": {
            "type": "String"
        },
       "webAppSlotName": {
            "type": "String"
        },
        "virtualApplications":{
        "type": "array",
        "defaultValue":[
            {
            "virtualPath": "/",
            "physicalPath": "site\\wwwroot\\webapps\\ROOT",
            "preloadEnabled": false,
            "virtualDirectories": null
            }
        ]
        }
  },
  "variables": {},
  "resources": [
      {
          "type": "Microsoft.Web/sites/config",
          "name": "[concat(parameters('webAppName'), '/web')]",
          "apiVersion": "2016-08-01",
          "properties": {
              "virtualApplications": "[parameters('virtualApplications')]"
          },
          "dependsOn": []
      },
      {
          "type": "Microsoft.Web/sites/slots/config",
          "name": "[concat(parameters('webAppName'),'/', parameters('webAppSlotName'),'/web')]",
          "apiVersion": "2016-08-01",
          "properties": {
              "virtualApplications": "[parameters('virtualApplications')]"
          },
          "dependsOn": []
      }
      
  ]
}
DEPLOY

  parameters = {
    "webAppName"          = "${azurerm_app_service.tomcat_apps[count.index].name}"
    "webAppSlotName"      = "${azurerm_app_service_slot.tomcat_app_slots[count.index].name}"

    # We use the a baked default value; I have not tried the below jsonencode; mostly because it is not easy to read.
  }

  depends_on = [
    "azurerm_app_service.tomcat_apps",
    "azurerm_app_service_slot.tomcat_app_slots"
  ]
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