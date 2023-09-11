# NutanixAHV-VMWareESXi
Converts Virtual Machine from Nutanix AHV to VMWare ESXi. 
-Gathers a list of VMs(PVMs) by user input (Seperate by commas)
-Iterates through each on the list. 
-Checks to see if VM is in cluster, checks CPU and RAM on VM.
-Sends VM a scheduled task to run after getting converted to register new DNS record.
-Powers off VM
-Starts SCP to download VDisk to local machine
-Converts VDisk to .VMDK via QEMU. 
-Converts VMWare Workstation VMDK to ESXi-Compatible VMDK via VMWorkstation-VDiskmanager.exe
-Uploads ESXi-Compatible VMDK to NutanixDisks datastore. 
-Delete old files off of local machine besides the log. 
-Spin up new VM based on a  template that has no hard disk. 
-Attach harddisk from datastore and power on. 
-Runs the scheduled task that registers new DNS record.

-There are several areas where you will need to enter information specific to your network. All of these have been identified by three asterisks (***). Please do a ctrl-f and search for *** to find all areas where your custom information is needed. 

-Requirements:
  - Nutanix Cmdlets installed. (can be downloaded from the hypervisor)
  - VMWare Workstation installed.
  - WinSCP Installed and an account with credentials that allows for downloading of files from Nutanix datastores.
  - VMWare PowerCLI installed along with rights neccesary to upload files to datastore.
  - Qemu which is used to convert Nutanix VDisk to VMWare ESXi compatible disk. (https://www.qemu.org/download/)
  - A folder will be created at C:\windows\config\logs that will contain logs and temporary disk files for download/upload purposes. 
