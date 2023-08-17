$resourceGroup="testrg"
$location="Australia Southeast"
$keyVaultName="bandakeyvault"
$keyName="bandakey"
$keyDestination="Software"
$diskEncryptionSetName="bandades"

#Create KeyVault
$keyVault = New-AzKeyVault -Name $keyVaultName `
-ResourceGroupName $ResourceGroup `
-Location $location `
-SoftDeleteRetentionInDays 90 `
-EnablePurgeProtection

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

#Stop the VM
Stop-AzVM `
-Name "testvm01" `
-ResourceGroupName $resourceGroup `
-Force

#Wait for 5mins(300seconds) for VM to be stopped completely
Start-Sleep -Seconds 300

#Update the encryption of OS disks of VM to Platform-managed and Customer-managed keys

$diskName = "testvm01_OsDisk_1_e93cb356b361476188595e5b79811cbc"
 
$diskEncryptionSet = Get-AzDiskEncryptionSet `
-ResourceGroupName $resourceGroup `
-Name $diskEncryptionSetName
 
New-AzDiskUpdateConfig `
-EncryptionType "EncryptionAtRestWithPlatformAndCustomerKeys" `
-DiskEncryptionSetId $diskEncryptionSet.Id | Update-AzDisk -ResourceGroupName $resourceGroup -DiskName $diskName

#Wait for 5mins(300seconds) for disks to be added to DES
Start-Sleep -Seconds 300

#Start the VM
Start-AzVM `
-Name "testvm01" `
-ResourceGroupName $resourceGroup

