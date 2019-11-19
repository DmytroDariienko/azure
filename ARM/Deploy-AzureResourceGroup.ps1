#Requires -Version 3.0
[string] [Parameter(Mandatory=$true)] $AzSubscriptionID = '1bc77437-fbfa-4a91-8cd6-ad1626dc5fd4'
[string] [Parameter(Mandatory=$true)] $ResourceGroupName ="ddaritest-rg"
[string] [Parameter(Mandatory=$true)] $ResourceGroupLocation="Central US"
[string] $TemplateFile = '.\APIManagemant\template.json'
[string] $TemplateParametersFile = '.\APIManagemant\parameters.json'
$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))
#Connect-AzAccount
Get-AzSubscription -SubscriptionId $AzSubscriptionID -ErrorAction Stop > $null
Set-AzContext -SubscriptionId $AzSubscriptionID -ErrorAction Stop > $null
# Create or update the resource group using the specified template file and template parameters file
Select-AzSubscription -SubscriptionId $AzSubscriptionID -ErrorAction Stop
New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -Verbose -Force
New-AzResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -ResourceGroupName $ResourceGroupName `
                                       -Mode Incremental `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       @OptionalParameters `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
}