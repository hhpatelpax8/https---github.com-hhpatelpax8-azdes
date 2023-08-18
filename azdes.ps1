$resourceGroup="testrg"
$location="Australia Southeast"
$objectid="3648c0d7-dae6-4e97-a90c-72e013aa1505"
$applicationid="795531ac-a378-4d0c-a53b-7881314d1275"
$keyVaultName="bandakeyvault011"
$keyName="bandakey11"
$keyDestination="Software"
$diskEncryptionSetName="bandades11"

#Create KeyVault
$keyVault = New-AzKeyVault -Name $keyVaultName `
-ResourceGroupName $ResourceGroup `
-Location $location `
-SoftDeleteRetentionInDays 90 `
-EnablePurgeProtection `

Set-AzKeyVaultAccessPolicy `
-VaultName $keyVaultName `
-ResourceGroupName $resourceGroup `
-ObjectId $objectid `
-ApplicationId $applicationid `
-PermissionsToKeys all `

#Create Key
$key = Add-AzKeyVaultKey -VaultName $keyVaultName `
-Name $keyName `
-Size 2048 `
-KeyType RSA `
-Destination $keyDestination

#Create Disk Encryption Set with double encryption
$desConfig=New-AzDiskEncryptionSetConfig `
-Location $location `
-EncryptionType "EncryptionAtRestWithPlatformAndCustomerKeys" `
-SourceVaultId $keyVault.ResourceId `
-KeyUrl $key.Key.Kid `
-IdentityType "SystemAssigned" `
-RotationToLatestKeyVersionEnabled $true
  
$des=New-AzDiskEncryptionSet `
-Name $diskEncryptionSetName `
-ResourceGroupName $ResourceGroup `
-InputObject $desConfig

#Allow DES to access key vault
Set-AzKeyVaultAccessPolicy `
-VaultName $keyVaultName `
-ObjectId $des.Identity.PrincipalId `
-PermissionsToKeys wrapkey,unwrapkey,get

#Get all the VMs in the specified ResourceGroup
$vms=Get-AzVM -ResourceGroupName $resourceGroup -Status
 
foreach ($vm in $vms) {
        Write-Host "VM $($vm.Name) Power State: $($vm.PowerState)"
        
        # Turn OFF running VMs
        if ($vm.PowerState -eq "VM running") {
            Write-Host "Stopping VM $($vm.Name)"
            Stop-AzVM -ResourceGroupName $resourceGroup -Name $vm.Name -Force
        }
}

#Wait for 1min(60seconds) for VM to be stopped completely
#Start-Sleep -Seconds 60

#Get all the VMs in the specified ResourceGroup
$vms=Get-AzVM -ResourceGroupName $resourceGroup -Status

#Get the Disk Name of stopped VMs
foreach ($vm in $vms) {
    if ($vm.PowerState -eq "VM deallocated") {
        $diskName = $vm.StorageProfile.OsDisk.Name
        Write-Host "VM $($vm.Name) is stopped and its Disk Name is: $diskName"

        # Get the disk encryption set
        $diskEncryptionSet = Get-AzDiskEncryptionSet -ResourceGroupName $resourceGroup -Name $diskEncryptionSetName
        
        if ($diskEncryptionSet) {
            # Update disk encryption
            $diskUpdateConfig = New-AzDiskUpdateConfig -EncryptionType "EncryptionAtRestWithPlatformAndCustomerKeys" -DiskEncryptionSetId $diskEncryptionSet.Id
            Update-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName -DiskUpdate $diskUpdateConfig
            Write-Host "Disk encryption updated for VM $($vm.Name)"
        } else {
            Write-Host "Disk encryption set '$diskEncryptionSetName' not found."
        }
    }
}

#Wait for 1min(60seconds) for disks to be added to DES
#Start-Sleep -Seconds 60

#Get all the VMs in the specified ResourceGroup
$vms=Get-AzVM -ResourceGroupName $resourceGroup -Status
 
foreach ($vm in $vms) {
        Write-Host "VM $($vm.Name) Power State: $($vm.PowerState)"
        
        # Turn ON running VMs
        if ($vm.PowerState -eq "VM deallocated") {
            Write-Host "Starting VM $($vm.Name)"
            Stop-AzVM -ResourceGroupName $resourceGroup -Name $vm.Name -Force
        }
}