param(
    [Parameter(Mandatory = $false, HelpMessage = 'for bulk changes, please provide path to CSV')]
    [string] $CSV,
    [Parameter(Mandatory = $false, HelpMessage = 'If no CSV import is being used, please provide the name of a single VM')]
    [string] $VMname,
    [Parameter(Mandatory = $false, HelpMessage = 'If no CSV import is being used, please the new desired SKU')]
    [string] $NewVMSize   
)
$error.Clear()

#Login to Azure subscription
Login-AzAccount

if ($CSV) {
    #check whether CSV import is being used
    $CSV = import-csv $CSV
    $CSV | % {
        $VMname = $_.VMName
        $NewVMSize = $_.sku
        
        $VM = Get-AzVM -Name $VMname -Status
        $RG = $VM.ResourceGroupName

        #get SKU information
        $sku = Get-AzVMSize -Location $vm.Location | ? { $_.name -eq $NewVMSize }
        $sku = $sku.NumberOfCores

        #check if VM has accelerated networking activated
        $tmp = (Get-AzVM -Name $VMname -ResourceGroupName $RG).NetworkProfile 
        $tmp = $tmp.NetworkInterfaces.ID.split("/")
        $vnic = $tmp[-1]
        $nic = Get-AzNetworkInterface -Name $vnic -ResourceGroupName $RG
        $acnw = $nic.EnableAcceleratedNetworking

        #get current vm size
        $CurrentVMSize = $VM.HardwareProfile.VmSize

        #check online Status of VM
        $VMstatus = $VM.PowerState
        if ($VMStatus -eq "VM running") {
            Write-Host "$VMname is running! Shutting down VM!" -ForegroundColor Black -BackgroundColor Yellow
            Stop-AzVM -ResourceGroupName $RG -Name $VMname -Force > $null
            Write-Host "$VMname stopped!" -ForegroundColor Black -BackgroundColor Yellow  
        }

        if ($acnw) {
            Write-Host "$VMname has accelerated networking enabled!" -ForegroundColor Black -BackgroundColor Yellow
            #check if accelerated networking is supported on new SKU // turn off accelerated networking if necessary
            if ($sku -lt 4) {
                Write-Host "New SKU does not support accelerated networking. Disabling..." -ForegroundColor Black -BackgroundColor Yellow
                $nic.EnableAcceleratedNetworking = $false
                $nic | Set-AzNetworkInterface > $null
            }
        }
        #re-size VM
        Write-Host "re-sizing $VMname from $CurrentVMSize to $NewVMsize..." -ForegroundColor Black -BackgroundColor Yellow  
        $vm.HardwareProfile.VmSize = $NewVMSize
        Update-AzVM -VM $vm -ResourceGroupName $RG > $null
        if ($error) {
            $error
        }
        else {
            Write-Host "$VMname successfully re-sized to $NewVMsize! Starting VM..." -ForegroundColor Black -BackgroundColor green  
            #start VM
            Start-AzVM -ResourceGroupName $RG -Name $VMname > $null
            do {
                $Status = Get-AzVM -Name $VMname -Status 
            } until ($Status.PowerState -eq "VM running")
            Write-Host "$VMname is running!" -ForegroundColor Black -BackgroundColor Green  
    
        }
    }   
}
else {    
    $VM = Get-AzVM -Name $VMname -Status
    $RG = $VM.ResourceGroupName

    #get SKU information
    $sku = Get-AzVMSize -Location $vm.Location | ? { $_.name -eq $NewVMSize }
    $sku = $sku.NumberOfCores

    #check if VM has accelerated networking activated
    $tmp = (Get-AzVM -Name $VMname -ResourceGroupName $RG).NetworkProfile 
    $tmp = $tmp.NetworkInterfaces.ID.split("/")
    $vnic = $tmp[-1]
    $nic = Get-AzNetworkInterface -Name $vnic -ResourceGroupName $RG
    $acnw = $nic.EnableAcceleratedNetworking

    #get current vm size
    $CurrentVMSize = $VM.HardwareProfile.VmSize

    #check online Status of VM
    $VMstatus = $VM.PowerState
    if ($VMStatus -eq "VM running") {
        Write-Host "$VMname is running! Shutting down VM!" -ForegroundColor Black -BackgroundColor Yellow
        Stop-AzVM -ResourceGroupName $RG -Name $VMname -Force > $null
        Write-Host "$VMname stopped!" -ForegroundColor Black -BackgroundColor Yellow  
    }

    if ($acnw) {
        Write-Host "$VMname has accelerated networking enabled!" -ForegroundColor Black -BackgroundColor Yellow
        #check if accelerated networking is supported on new SKU // turn off accelerated networking of necessary
        if ($sku -le 4) {
            Write-Host "New SKU does not support accelerated networking. Disabling..." -ForegroundColor Black -BackgroundColor Yellow
            $nic.EnableAcceleratedNetworking = $false
            $nic | Set-AzNetworkInterface > $null
        }
    }
    #re-size VM
    Write-Host "re-sizing $VMname from $CurrentVMSize to $NewVMsize..." -ForegroundColor Black -BackgroundColor Yellow  
    $vm.HardwareProfile.VmSize = $NewVMSize
    Update-AzVM -VM $vm -ResourceGroupName $RG > $null
    if ($error) {
        $error
    }
    else {
        Write-Host "$VMname successfully re-sized to $NewVMsize! Starting VM..." -ForegroundColor Black -BackgroundColor green  
        #start VM
        Start-AzVM -ResourceGroupName $RG -Name $VMname > $null
        do {
            $Status = Get-AzVM -Name $VMname -Status 
        } until ($Status.PowerState -eq "VM running")
        Write-Host "$VMname running!" -ForegroundColor Black -BackgroundColor Green  

    }
}
