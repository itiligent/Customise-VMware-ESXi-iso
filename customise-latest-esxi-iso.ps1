##############################################################################################
#     ____________  __ _    _                               __          _ __    __         
#    / ____/ ___/ |/ /(_)  (_)___ ___  ____ _____ ____     / /_  __  __(_) /___/ /__  _____
#   / __/  \__ \|   // /  / / __ `__ \/ __ `/ __ `/ _ \   / __ \/ / / / / / __  / _ \/ ___/
#  / /___ ___/ /   |/ /  / / / / / / / /_/ / /_/ /  __/  / /_/ / /_/ / / / /_/ /  __/ /    
# /_____//____/_/|_/_/  /_/_/ /_/ /_/\__,_/\__, /\___/  /_.___/\__,_/_/_/\__,_/\___/_/     
#                                         /____/                                           
# Get ESXi running on non HCL hardware. (Adds support for most NVMEs & Intel consumer NICs) 
##############################################################################################
# David Harrop
# April 2022
##############################################################################################
# Install VMware PowerCLI FIRST!
# (You must be Administrator to install PowerCLI. 
# No need to be administrator to run the rest)
# 
# Install VMware PowerCLI
# then run:
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
# Install-Module -Name VMware.PowerCLI -SkipPublisherCheck
#
# Uncomment lines marked ##@@ to enable USB drivers - this will not work with latest version
# of iso export, but it should work for an exported bundle
##############################################################################################

$baseESXiVer = "7"
#Update the below driver file names manually. USB has compatibility issues so it is disbled at present 
##@@$usbFling = "ESXi703-VMKUSB-NIC-FLING-51233328-component-18902399.zip"
$nicFling = "Net-Community-Driver_1.2.7.0-1vmw.700.1.0.15843807_19480755.zip"
$nvmeFling = "nvme-community-driver_1.0.1.0-3vmw.700.1.0.15843807-component-18902434.zip"

echo ""
echo "Grab a cuppa...this may take a while!"
echo ""
echo "Retrieveing latest ESXi bundle"
echo ""

Add-EsxSoftwareDepot https://hostupdate.vmware.com/software/VUM/PRODUCTION/main/vmw-depot-index.xml
$imageProfile = (Get-EsxImageProfile -Name "ESXi-$baseESXiVer*-standard*" | Sort-Object -Property 'Name' -Descending | Select-Object -First 1).Name
if (!(Test-Path "$($imageProfile).zip")){Export-ESXImageProfile -ImageProfile $imageProfile -ExportToBundle -filepath "$($imageProfile).zip"}
Get-EsxSoftwareDepot | Remove-EsxSoftwareDepot

echo ""
echo "Finishd retrieving latest ESXi Bundle"
echo ""

##@@if (!(Test-Path $usbFling)){Invoke-WebRequest -Method "GET" https://download3.vmware.com/software/vmw-tools/USBNND/$($usbFling) -OutFile $($usbFling)}
if (!(Test-Path $nicFling)){Invoke-WebRequest -Method "GET" https://download3.vmware.com/software/vmw-tools/community-network-driver/$($nicFling) -OutFile $($nicFling)}
if (!(Test-Path $nvmeFling)){Invoke-WebRequest -Method "GET" https://download3.vmware.com/software/vmw-tools/community-nvme-driver/$($nvmeFling) -OutFile $($nvmeFling)}

echo ""
echo "Adding the custom nic and nvme drivers to the local depot"
echo ""

Add-EsxSoftwareDepot "$($imageProfile).zip"
#Add-EsxSoftwareDepot $usbFling
Add-EsxSoftwareDepot $nicFling
Add-EsxSoftwareDepot $nvmeFling

echo ""
echo "Creating the custom image profile" 
echo ""

$newProfile = New-EsxImageProfile -CloneProfile $imageProfile -name $($imageProfile.Replace("standard", "nic-nvme")) -Vendor "DH Custom"

echo ""
echo "Injecting the extra drivers into the custom profile"
echo ""

##@@Add-EsxSoftwarePackage -ImageProfile $newProfile -SoftwarePackage "vmkusb-nic-fling" -Force
Add-EsxSoftwarePackage -ImageProfile $newProfile -SoftwarePackage "net-community" -Force
Add-EsxSoftwarePackage -ImageProfile $newProfile -SoftwarePackage "nvme-community" -Force

echo ""
echo "Exporting the new ESXi build to ISO"
echo ""

Export-ESXImageProfile -ImageProfile $newProfile -ExportToIso -filepath "$($imageProfile.Replace("standard", "nic-nvme")).iso" -Force
#Export-ESXImageProfile -ImageProfile $newProfile -ExportToBundle -filepath "$($imageProfile.Replace("standard", "nic-nvme")).zip" -Force

Get-EsxSoftwareDepot | Remove-EsxSoftwareDepot
echo ""
echo "Build complete!"
echo ""
