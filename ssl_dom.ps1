$resourcegroupname = "tomcat-a"
$pfxPath = "/home/dmytro/ssl.pfx"
$pfxPassword = $Args[0]

Write-Host "Configure a CNAME record that maps www.ddaritestapp.tk to tomcat-app-us.azurewebsites.net"

Set-AzWebApp -Name "tomcat-app-us" -ResourceGroupName $resourcegroupname -HostNames @("www.ddaritestapp.tk","tomcat-app-us.azurewebsites.net")

New-AzWebAppSSLBinding -WebAppName "tomcat-app-us" -ResourceGroupName $resourcegroupname -Name "www.ddaritestapp.tk" -CertificateFilePath $pfxPath -CertificatePassword $pfxPassword -SslState SniEnabled

Write-Host "Configure a CNAME record that maps ddaritestapp.tk to tomcat-app-eu.azurewebsites.net"

Set-AzWebApp -Name "tomcat-app-eu" -ResourceGroupName $resourcegroupname -HostNames @("ddaritestapp.tk","tomcat-app-eu.azurewebsites.net")

New-AzWebAppSSLBinding -WebAppName "tomcat-app-eu" -ResourceGroupName $resourcegroupname -Name "ddaritestapp.tk" -CertificateFilePath $pfxPath -CertificatePassword $pfxPassword -SslState SniEnabled