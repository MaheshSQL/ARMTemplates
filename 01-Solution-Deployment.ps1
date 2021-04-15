#----------------------------------------------------------------------------------
#Ref: https://github.com/Azure/azure-quickstart-templates
#----------------------------------------------------------------------------------

#Login to Azure and set subscription
Connect-AzAccount -Subscription <YourSubscriptionID>
Set-AzContext -Subscription <YourSubscriptionID>
Get-AzContext

#Misc
#az keyvault purge --name keyvaultname
#Remove-AzKeyVault -VaultName ContosoVault -InRemovedState -Location AustraliaEast

#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------

$resourceGroupName = "rg-xxxxxxxxxxxxxxx"     #New resource group to be created.
$resourceGroupLocation = "EnterLocationName"  #e.g. "Australia East"
$vNetName = "VNET-xxxxxxxxxx"                 #This should be same as what you have entered in .parameters.json files.
$subnetName = "AzureMLSubnet"                 #This should be same as what you have entered in .parameters.json files.

#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
Write-Output "Deploying resource Group ############################"
#Create a new resource group
New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
$deploymentPrefix = "vNet-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

Write-Output "Deploying vNet and Subnets ############################"
#Deploy vNet to the resource group
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\01-vNet.json `
  -TemplateParameterFile .\01-vNet.parameters.json
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------

$deploymentPrefix = "BastionWithNSG-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

Write-Output "Deploying Bastion with NSG ############################"
#Deploy Bastion with NSG
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\02-Bastion-withNSG.json `
  -TemplateParameterFile .\02-Bastion-withNSG.parameters.json
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
$dsvmType = ""
$dsvmType = Read-Host "Please enter DSVM type [WINDOWS/LINUX]?"

if ($dsvmType -eq "WINDOWS")
{
  $deploymentPrefix = "WindowsDSVM-"
  $today = Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
  $deploymentName = $deploymentPrefix + "-" + "$today"

  Write-Output "Deploying Windows DSVM without Public IP ############################"
  #Deploy DSVM
  New-AzResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile .\03-DSVM-Windows.json `
    -TemplateParameterFile .\03-DSVM-Windows.parameters.json
}

if ($dsvmType -eq "LINUX")
{
  $deploymentPrefix = "LinuxDSVM-"
  $today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
  $deploymentName= $deploymentPrefix + "-" +"$today"

  Write-Output "Deploying Linux DSVM without Public IP ############################"
  #Deploy DSVM
  New-AzResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile .\03-DSVM-Linux.json `
    -TemplateParameterFile .\03-DSVM-Linux.parameters.json
}

$createPIP = "N"
$createPIP = Read-Host "Do you want to create a Public IP for the DSVM [Y/N]?"

if ($createPIP -eq "Y") 
{
  Write-Host "Creating PIP.."
  #Adding public IP (not recommended) step to the VM (When Bastion/VPN options were not selected)
  $pipname = "<EnterPIPName>"
  $nicname = "<EnterNICName>"
  $ipconfigname = "<EnterExistingIPConfigName>" #In Azure Portal, NIC resource -> Settings -> IP configurations

  #Create a Public IP
  New-AzPublicIpAddress -Name $pipname -ResourceGroupName $resourceGroupName -AllocationMethod Dynamic -Location $resourceGroupLocation

  #Associate PIP to VM's NIC
  $vnet = Get-AzVirtualNetwork -Name $vNetName -ResourceGroupName $resourceGroupName
  $subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
  $nic = Get-AzNetworkInterface -Name $nicname -ResourceGroupName $resourceGroupName
  $pip = Get-AzPublicIpAddress -Name $pipname -ResourceGroupName $resourceGroupName
  $nic | Set-AzNetworkInterfaceIpConfig -Name $ipconfigname -PublicIPAddress $pip -Subnet $subnet
  $nic | Set-AzNetworkInterface
}
else 
{
  Write-Host "PIP creation skipped.."
}
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#Note: If below deployment fails due to Storage account deployment failute then delete the resources deployed by below (also purge key vault) and re-run.

$deploymentPrefix = "AzureMLwithPE-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"
  
Write-Output "Deploying Azure ML Workspace with PE ############################"
#Deploy Azure ML Workspace
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\04-AzureMLWorkspace-PE.json `
  -TemplateParameterFile .\04-AzureMLWorkspace-PE.parameters.json
  
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------

$check = Read-Host "Please update the 05-AzureML-AllResources-PE.parameters.json with AML Resourcenames printed above and press enter."

$deploymentPrefix = "AzureMLResourcesPE-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

Write-Output "Deploying Azure ML Resources PE ############################"
#Deploy Azure ML Workspace
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\05-AzureML-AllResources-PE.json `
  -TemplateParameterFile .\05-AzureML-AllResources-PE.parameters.json



#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------

$deploymentPrefix = "AzureMLComputeClusterNoPIP-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

#Actually required for deploying no PIP AML Compute Cluster (Already configured for AzureMLSubnet in '01-vNet.json' ARM template file, so not required to be run.)
#ALTERNATIVELY, output of below line shows the status of 'privateEndpointNetworkPolicies' and 'PrivateLinkServiceNetworkPolicies', both need to be disabled to use AML Cluster without PIP
az network vnet subnet update --name AzureMLSubnet --resource-group $resourceGroupName --vnet-name $vNetName --disable-private-endpoint-network-policies true  

Write-Output "Deploying Azure ML Cluster without PIP ############################"
#Deploy Azure ML Workspace Cluster
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\06-AzureML-Cluster-NoPIP.json `
  -TemplateParameterFile .\06-AzureML-Cluster-NoPIP.parameters.json

#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------


$deploymentPrefix = "ADLSGen2-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

Write-Output "Deploying ADLS Gen2 Storage ############################"
#Deploy ADLSGen2
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\07-ADLS-Gen2.json `
  -TemplateParameterFile .\07-ADLS-Gen2.parameters.json

#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------


$deploymentPrefix = "ADLSGen2-PE-"
$today=Get-Date -Format "MM-dd-yyyy-hh-mm-ss"
$deploymentName= $deploymentPrefix + "-" +"$today"

Write-Output "Deploying Private Endpoints for ADLS Gen2 Storage ############################"
#Deploy PE for ADLSGen2 (Deployed in step above)
New-AzResourceGroupDeployment `
  -Name $deploymentName `
  -ResourceGroupName $resourceGroupName `
  -TemplateFile .\08-ADLS-Gen2-PE.json `
  -TemplateParameterFile .\08-ADLS-Gen2-PE.parameters.json

#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#Now create Budget and cost alert on the resource group.
#Test VM Connectivity from Bastion.
#Test AML and Storage connectivity from VM.
#Done.
#----------------------------------------------------------------------------------