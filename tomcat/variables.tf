variable "lacations" {
  type    = list(string)
  default = ["Central US", "West Europe"]
}

variable "plan_names" {
  type    = list(string)
  default = ["tomcat-plan-us", "tomcat-plan-eu"]
}

variable "autoscale_names" {
  type    = list(string)
  default = ["tomcat-plan-us-autoscale", "tomcat_plan-eu-autoscale"]
}

variable "app_names" {
  type    = list(string)
  default = ["tomcat-app-us", "tomcat-app-eu"]
}