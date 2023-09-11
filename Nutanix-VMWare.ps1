Add-PSSnapin NutanixCmdletsPSSnapin
function 
Connect-VMWare
{
  $VMusername = "VMWareUserName***"
    $VMpassword = "VMWarePassword***"
    $secpasswd = ConvertTo-SecureString $VMpassword -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ($VMusername, $secpasswd)
    Connect-VIServer -Server "ServerNameVMWARE***" -Credential $mycreds 
    }

function Stop-NutanixVM
{
    param (
        [parameter(mandatory=$true)]$computer
    )
            $TaskID = (Set-NTNXVMPowerOff -Vmid (Get-NTNXVM | Where-Object vmname -eq $computer | Select-Object UUID).uuid).taskUuid
           do
           {
               Start-Sleep 2
               $status = Get-NTNXTask -Taskid $TaskID | Select-Object -expandproperty progressStatus
           }
           until (($status -eq 'Succeeded') -or ($Status -eq 'Failed'))
           If ($status -eq 'Failed') {
            Write-Error "Nutanix was unable to power off the VM please check Prism"
           }
}


function Connect-Nutanix 
{
    param(
        [parameter(mandatory=$false)]$ClusterName,
        [parameter(mandatory=$true)]$NutanixClusterUsername,
        [parameter(mandatory=$true)]$NutanixClusterPassword
    )
#Convert the Nutanix cluster password to a secure string
    $NutanixClusterPassword=$NutanixClusterPassword | ConvertTo-SecureString -AsPlainText -Force
#first check if the NutanixCmdletsPSSnapin is loaded, load it if its not, Stop script if it fails to load
    if ( $null -eq (Get-PSSnapin -Name NutanixCmdletsPSSnapin -ErrorAction SilentlyContinue) )
    {
        Add-PsSnapin NutanixCmdletsPSSnapin -ErrorAction Stop
    }
    $connection = Get-NutanixCluster
#If not connected to a cluster or the connection is older than 1 hour, then connect/reconnect
    if(!$connection.IsConnected -or ([datetime]$connection.lastAccessTimestamp -lt (Get-Date).AddHours(-1)))
    {
        if ($connection.IsConnected)
        {
            Disconnect-NTNXCluster $connection.server
        }
#If not already connected to a cluster, prompt for inputs on the cluster/username/password to connect
    #If the ClusterName Parameter is passed, connect to that cluster, otherwise prompt for the clustername
        if($ClusterName)
        {
            $NutanixCluster = $ClusterName
        }
        else
        {
            $NutanixCluster = (Read-Host "Nutanix Cluster")
        }
        $connection = Connect-NutanixCluster -server $NutanixCluster -username $NutanixClusterUsername -password $NutanixClusterPassword -AcceptInvalidSSLCerts -ForcedConnection
        if ($connection.IsConnected)
        {
            #connection success
            Write-Output "Connected to $($connection.server)"
        }
        else{
            #connection failure, stop script
            Write-Warning "Failed to connect to $NutanixCluster"
            Break
        }
    }
    else{
        #make sure we're connected to the right cluster
        if($ClusterName -and ($ClusterName -ne $($connection.server)))
        {
            #we're connected to the wrong cluster, reconnect to the right one
            Disconnect-NTNXCluster $connection.server
            $connection = Get-NutanixCluster
            $NutanixCluster = $ClusterName
            $connection = Connect-NutanixCluster -server $NutanixCluster -username $NutanixClusterUsername -password $NutanixClusterPassword -AcceptInvalidSSLCerts -ForcedConnection
            if ($connection.IsConnected)
            {
                #connection success
                Write-Output "Connected to $($connection.server)"
            }
            else
            {
                #connection failure, stop script
                Write-Warning "Failed to connect to $NutanixCluster"
                Break
            }
        }
    }
    return [bool]$connection.IsConnected
}




function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("LogContent")]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [Alias('LogPath')]
        [string]$Path=$log,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Error","Warn","Info")]
        [string]$Level="Info",

        [Parameter(Mandatory=$false)]
        [switch]$NoClobber
    )

    Begin
    {
        # Set VerbosePreference to Continue so that verbose messages are displayed.
        $VerbosePreference = 'Continue'
    }
    Process
    {

        # If the file already exists and NoClobber was specified, do not write to the log.
        if ((Test-Path $Path) -AND $NoClobber) {
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name."
            Return
            }

        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path.
        elseif (!(Test-Path $Path)) {
            Write-Verbose "Creating $Path."
            New-Item $Path -Force -ItemType File
            }

        # Format Date for our Log File
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Write message to error, warning, or verbose pipeline and specify $LevelText
        switch ($Level) {
            'Error' {
                Write-Error $Message
                $LevelText = 'ERROR:'
                }
            'Warn' {
                Write-Warning $Message
                $LevelText = 'WARNING:'
                }
            'Info' {
                Write-Verbose $Message
                $LevelText = 'INFO:'
                }
            }

        # Write log entry to $Path
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append
    }
    End
    {
    }
}

function New-VSVM
{

    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Computername,
        [string]$Template,
        [string]$DataStore,
        [string]$NetworkName = 'Internal1',
        [string]$VMHost,
        [string]$VCenter,
        [string]$Location,
        [string]$DiskStorageFormat

    )

        New-VM -Name $computername -VMHost $VMHost -Template $Template -Datastore $Datastore -Location $Location -DiskStorageFormat $DiskStorageFormat

    }


#--------Receives PVM names from user in Jenkins and splits them up by comma if entered that way----------------# 
$vmname = read-host "Enter VM Name:   "
$clustername = read-host "Enter Nutanix Cluster name: "
$Comps = $vmname   #Add ENV before VMName
$assetssplit = $VMname.Split(",")
new-item C:\windows\config\logs -ItemType Directory -Force
Connect-VMWare
#For each PVM that is entered...
foreach($VMAsset in $assetssplit){
    $VMname = $VMasset.replace(' ','')

    #----------------------Gets UUIDs from entered information in Jenkins-------------------------------------------#
     Add-PsSnapin NutanixCmdletsPSSnapin
             $username = "NutanixClusterUsername***"
             $password = "NutanixClusterPassword***"
             Connect-Nutanix -ClusterName $clustername -NutanixClusterUsername $username -NutanixClusterPassword $password -ErrorAction Continue
             $VM =  Get-NTNXVM -SearchString $vmName -ErrorAction Ignore
             $PVMName = $VM.VMName 
            
    
         
       
    #---------Uses VM variable to get VDiskUUID, checks to see which cluster the PVM is on--------------------------#
    $PVMVDiskUUID = $vm.nutanixVirtualDiskIds 
    Write-output "UUID of VM is $PVMDiskUUID"
    $ipaddress = (Resolve-DnsName -Name $pvmname | select IPAddress).ipaddress
    $owner = $VM.description
    $Options = $PVMVDiskUUID.split(":")
    $pvmuuid = $Options[2]
    $CPUs = $vm.numVCpus
    $MemoryInBytes = $vm.memoryCapacityInBytes
    if ($MemoryInBytes -eq "17179869184"){
    $RAM = 16
    }
    else{$RAM = 8}
    #-------Sets up names and directories for logs and VMDK destination--------------------------------------------#
    $PVMLocalFolder = "C:\Windows\config\logs\NutanixConversions\$vmname"
    $testpath = Test-Path $PVMLocalFolder
    If ($testpath){
      #  remove-item $PVMLocalFolder -Recurse -force -ErrorAction Ignore
    }
   # new-item $pvmlocalfolder -ItemType Directory
   
    $log = "$PVMlocalfolder\$vmname.log"
    Write-log -path $log -Message "VMName is $PVMName"
    Write-log -path $log -Message "VM Cluster is $clustername"
    Write-log -path $log -Message "VDisk UUID is $PVMUUID"
    Write-log -path $log -message "RAM is $RAM"
    write-log -path $log -message "Owner is $owner"

#-----------------------------------------Copy PS1 for DNS to VM before shutting down--------------------------------#
write-log -Path $log -Message "Copying PS1 for task to $pvmname"
$content = 
'
$comp = $env:COMPUTERNAME
$path = "C:\windows\config\logs\NEWDNS.log"
$dnstest = nslookup $comp
$dnscount = $dnstest.count
if ($dnscount -eq 3){
write-log -path $path -Message "Registering DNS"
$IPConfig = ipconfig /registerdns
$ipconfig >> $path
}
elseif ($dnscount -eq 6){
write-log -path $path -Message "DNS Already Registered. Clearing Scheduled Task"
unregister-scheduledtask -TaskName "VMWareDNSUpdate" -Confirm:$false
}
'
$OutfileLocation = "C:\windows\config\logs\NutanixVMWare"
$OutfileTestpath = test-path $OutfileLocation
if ($OutfileTestpath){
remove-item -Path $OutfileLocation -Recurse -Force
}
new-item -Path C:\windows\config\logs\ -Name NutanixVMWare -ItemType Directory
new-item -path C:\windows\config\logs\NutanixVMWare -name DNSUpdate.ps1
$outfile = "C:\windows\config\logs\NutanixVMWare\DNSUpdate.ps1"
$content | out-file $outfile
invoke-command -ComputerName $vmname -scriptblock {
new-item -Path C:\windows\config\logs\ -Name NutanixVMWare -ItemType Directory -Force
}
copy-item $outfile -Destination "\\$vmname\c$\windows\config\logs\NutanixVMWare" -force -ErrorAction Ignore

#----------------------------------------Setup scheduled task to run PS1 copied over---------------------------------#
write-log -Path $log -Message "Setting up scheduled task on $pvmname for DNS registering"
invoke-command -ComputerName $vmname -ScriptBlock {
$action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-noprofile -Windowstyle hidden -file "C:\windows\config\logs\NutanixVMWare\DNSUpdate.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -at ((get-date).AddMinutes(4)) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
Register-ScheduledTask -user "SYSTEM" -Settings $settings -RunLevel Highest -Action $action -Trigger $trigger -TaskName "VMWareDNSUpdate" -Description "Registers DNS name after VMWare conversion"
}
  

#-----------------------------------------Power Off VM before conversion---------------------------------------------#
    try{
    Connect-Nutanix -ClusterName $clustername -NutanixClusterUsername "$username" -NutanixClusterPassword "$password" | Out-Null
    Stop-NutanixVM -computer $vmname
    Write-log -Path $log -Message "$pvmname located in $clustername. Powering off."
    Write-output "$vmname located in $clustername"
    Write-output "$vmname Powered Off"
    }
    Catch{
    Write-output "$VMname was not located in $clustername"
    }
    



    #-------------------Start WINSCP functioning to set up session and transfer NTNX VDisk to Destination----------#
    Write-log -path $log -message "Setting up WinSCP for file transfer to cluster"
    #Setting up WINSCP for downloading of NTNX VDisks. 
    # Load WinSCP .NET assembly
    [Reflection.Assembly]::LoadFrom(“C:\Program Files (x86)\WinSCP\WinSCPnet.dll”) | Out-Null
    $ServerName = $clustername

    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions
    $sessionOptions.PortNumber = 2222
    $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
    $sessionOptions.HostName = $ServerName
    $sessionOptions.UserName = "WINSCPUsername***"
    $sessionOptions.Password = "WINSCPPassword***"
    #$sessionOptions.SshHostKeyFingerprint = “ssh-rsa 1024 xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx” # this feature is disabled in the next line.
    # Note I disabled the above line, and enabled the line below using instructions from:
    # http://winscp.net/eng/docs/library_sessionoptions
    $sessionOptions.GiveUpSecurityAndAcceptAnySshHostKey = $true

    $session = New-Object WinSCP.Session
    # note for more info, see http://winscp.net/eng/docs/library_session
    Try{
        # Connect
        $session.Open($sessionOptions)
        Write-log -path $log -Message "Successfully able to connect to $servername, initiating transfer"
    }
    Catch{
        Write-log -path $log -Message "Unable to connect to $servername, exiting program"
        Exit
    }

    # Set transfer mode to binary
    # note, for more info, see: http://winscp.net/eng/docs/library_transferoptions
    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    #Sends Nutanix File from VM determined from user input to destination folder. 

    $SourcePath = "/SelfServiceContainer/.acropolis/vmdisk/$PVMUUID"
    Try{
        $session.GetFiles("$SourcePath", "$PVMlocalfolder\", $False, $transferOptions) 
        Write-log -Path $log -Message "Successfully transferred Vdisk to destination folder"
    }
    Catch{
        write-log -Path $log -Message "Unable to transfer VDisk to destination folder, exiting program"
        exit
    }
     Write-log -Path $log "WINSCP download completed."
     start-sleep 30
     
     
     
    



    #----------------------------Sends NTNX VDisk to Qemu for conversion to VMDK----------------------------------#
    
    #if file is still filepart, removed .filepart from extension
    $filepart = get-childitem $PVMLocalFolder | where name -like "*.filepart*" -ErrorAction Ignore
    if ($filepart){
    $filepathName = $filepart.FullName
    $ReducedName = $filepart.BaseName
    rename-item -Path $filepathname -NewName $pvmlocalfolder\$reducedname -Force
    }
    Write-log -Path $log "Starting QEMU conversion"

  #---------------------------Must send Nutanix file to Qemu for conversion to VDMK-------------------------#
    Write-log -Path $log -Message "Starting CMD for conversion to .vmdk"
    "C:" >> C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname.ps1
    "cmd /C 'cd C:\Program Files\qemu && qemu-img.exe convert -O vmdk $PVMlocalfolder\$PVMUUID $PVMlocalfolder\$PVMName.VMDK'" >> C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname.ps1
    $command = "C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname.ps1"
    Invoke-Expression $command
    $QEMUVMDK = "C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname.VMDK"
     Write-log -Path $log "QEMU conversion completed."

    #Remove VDisk (125GB) to clear space
    Write-log -Path $log "Removed VDisk to clear space"
    Get-childitem $PVMLocalFolder -Recurse | where name -NotLike "*.log" | where name -NotLike "*.vmdk" |remove-item -Recurse -Force -ErrorAction Ignore


   #----------------------------Sends .VMDK to VMWARE-VDdiskmanager.exe for conversion to ESXI compatible--------------#
   Write-log -Path $log "Starting VMWare ESXI Conversion"
     new-item -Path $PVMLocalFolder\FinalVMDKs\ -ItemType Directory
     "C:" >> C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname-VDiskManager.ps1
     "cmd /C 'cd C:\Program Files (x86)\VMware\VMware Workstation\ && vmware-vdiskmanager.exe -r $QEMUVMDK -t 4 C:\Windows\config\logs\NutanixConversions\$pvmname\FinalVMDKs\$PVMName.vmdk'" >> C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname-VDiskManager.ps1
     $command = "C:\Windows\config\logs\NutanixConversions\$pvmname\$pvmname-VDiskManager.ps1"
     Invoke-Expression $command
     $FinalConvertedVMDK = "$pvmlocalfolder\FinalVMDKs\$pvmname.vmdk"
     $FinalConvertedVMDKFLAT = "$pvmlocalfolder\FinalVMDKs\$pvmname-flat.vmdk"
     Write-log -Path $log "VMWare ESXI Conversion completed."
 
     
 #-----------------------------------------Upload VMDK to NutanixDisks folder in Datastore---------------------------------#
    Write-log -Path $log "Starting VMDK upload to VMWare."
    
    $datastore = Get-Datastore -Server "VMWareServer***" -name "DatastoreName***"
    New-PSDrive -Location $Datastore -Name VMStorage -PSProvider VimDatastore -Root "\"
    $destination = 'VMStorage:\NutanixDisks/'
    New-Item -Path $destination -ItemType Directory -name $pvmname
    Copy-DatastoreItem -Item $FinalConvertedVMDK -Destination $destination
    Copy-DatastoreItem -Item $FinalConvertedVMDKFLAT -Destination $destination
    Write-log -Path $log "VMDK upload completed."


  #------------------------create new VM in VMWare with EUCEngTemplate----------------------------------------------#
    Write-log -Path $log "Creating new VM in VMWare using template"
        $Folder = Get-Folder "FolderLocation of new VM Goes here***"
        $Network ='Network Goes Here***'
	    $VMHost = Get-Cluster -Name 'ClusterName***' | Get-VMHost | where Connectionstate -eq "Connected" | Get-Random 
        $Template = Get-Template "TemplateHere****"
        $ISO = "IsoPathGoesHere***"
        New-VSVM -VCenter $VCenter -Computername $PVMName -DataStore 'DataStoreGoesHere***' -VMHost $VMHost -Template "TemlateGoesHere***" -Location $Folder -DiskStorageFormat Thin -NetworkName $Network
        start-sleep 30

 #---------------------------------Attach disk to VM and fire it up-------------------------------------------------#
    write-log "Attaching hard disk to VM"
         New-HardDisk -VM $PVMName -DiskPath "[DiskPath***] NutanixDisks/$pvmname.vmdk" -Confirm:$false
         start-sleep 30

  #----------------------------------Alter CPU and RAM----------------------------------------------------------#
    Write-log -path $log "Setting $CPUs CPU(s) and $RAM GB of RAM to $pvmname"
    set-vm -VM $PVMName -NumCpu $CPUs -MemoryGB $RAM -Confirm:$false
    set-vm -vm $pvmname -Notes "$owner" -Confirm:$false
    stop-vm -VM $PVMName -ErrorAction Ignore -Confirm:$false

 #-------------------------------------Start VM---------------------------------------------------------------#
    Write-log -Path $log "Starting $pvmname"
     Get-VM $pvmname | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName 'NetworkName***'  -Confirm:$false

    #Cleanup C:\ drive besides log file
    Write-log -Path $log "Cleaning Drive..."
    Get-childitem $PVMLocalFolder -Recurse | where name -NotLike "*.log"| remove-item -Recurse -Force -ErrorAction Ignore


}
