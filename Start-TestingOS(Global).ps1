function Start-TestingOS {
	<#
.Synopsis
   Script for perform basic testing on Weekends post OS Patching
.DESCRIPTION
   The script contains the following functions:
   1. Read and check the status of all services
   2. Check the UpTime of the server to see if the server was rebooted correctly
   3. Check the disk space of the server
   4. Check the performance of the server
	 5. Check the version, build and name of the system installed
	 6. Check the following on the IIS:
	 	Check if the Application Pools are "Started" (In App & Web)
	 	Check if the IIS Sites are "Started" (In App & Web)

.PARAMETER server
	Name of server to execute the functions
.PARAMETER APPpoolListPath
	Path of the file that contains the App Pool List for APP servers
.PARAMETER WEBpoolListPath
	Path of the file that contains the App Pool List for WEB servers
.PARAMETER APPsiteListPath
	Path of the file that contains the IIS site List for APP servers
.PARAMETER WEBsiteListPath
	Path of the file that contains the IIS site List for WEB servers

.EXAMPLE
	Get-AllServicesStatus -server
.EXAMPLE
	Get-SystemUptime -server
.EXAMPLE
	Get-DiskSpace -server
.EXAMPLE
	Get-CPUMemoryUsage -server
.EXAMPLE 
	Get-UpToDate -server 
.EXAMPLE
	Get-APPApplicationPoolStatus -server  -APPpoolListPath $APPpoolListPath
.EXAMPLE
	Get-WEBApplicationPoolStatus -server  -WEBpoolListPath $WEBpoolListPath
.EXAMPLE
	Get-WEBIISSiteStatus -server  -WEBsiteListPath $WEBsiteListPath
.EXAMPLE
	Get-APPIISSiteStatus -server  -APPsiteListPath $APPsiteListPath

#>
	# Here starts to save the process in a specific path with the date of today.

	#$logFile = "$PSScriptRoot -ChildPath\PostOSTesting $(Get-Date -Format yyyy-MM-dd).txt" #(FOR POWERSHELL OR SHP MANAGEMENT SHELL)
	$logFile = "$psISE.CurrentFile.FullPath\PostOSTesting $(Get-Date -Format yyyy-MM-dd).txt" #(FOR POWERSHELL ISE)
	Start-Transcript $logFile -Append -IncludeInvocationHeader

	############################ Define Server & Services Variable ###############
	$CurrentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	$WorkstationName = [System.Net.Dns]::GetHostName()
	#$serverListPath = Get-Content "$PSScriptRoot\ServerList.txt" (FOR POWERSHELL OR SHP MANAGEMENT SHELL)
	$serverListPath = Get-Content "$psISE.CurrentFile.FullPath\ServerList.txt" #(FOR POWERSHELL ISE)
	Import-Module PSWindowsUpdate
	#Import-Module "$PSScriptRoot\ScriptModule.psm1" (FOR POWERSHELL OR SHP MANAGEMENT SHELL)
	#Import-Module "$psISE.CurrentFile.FullPath\ScriptModule.psm1"

	Write-Host "Welcome" $CurrentUserName
	Write-Host "############################### System Uptime Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the details..." -ForegroundColor Cyan

	# Iterate through the servers and call the functions
	foreach ($server in $serverListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$systemUptime = Get-SystemUptime -Server $server
		Write-Output "Last Boot Uptime of $server :" $systemUptime
	}

	Write-Host "############################### Disk Status ############################### " -ForegroundColor Magenta
	Write-Host "Color Coding" -ForegroundColor Cyan
	Write-Host "------------------------" -ForegroundColor Cyan
	Write-Host "WARNING: More than 75% used" -ForegroundColor Yellow
	Write-Host "CRITICAL: More than 90% used" -ForegroundColor Red
	Write-Host "OK : Less than 75% used:" -ForegroundColor Green
	Write-Host "`n"
	Start-Sleep -Seconds 3
	Write-Host "Please wait while computing the Disks details..." -ForegroundColor Cyan
	Write-Host "`n"
	Start-Sleep -Seconds 3

	# Iterate through the servers and call the functions
	foreach ($server in $serverListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$disk = Get-DiskSpace -Server $server
		Write-Output "Disks status of $server :" $disk
	}

	Write-Host "`n"
	Write-Host "############################### CPU & Memory Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the CPU & Memory Performance..." -ForegroundColor Cyan
	Write-Host "--------------------------------" -ForegroundColor Cyan
	Write-Host "NOTE: The below values are expressed in % (Percentage)" -ForegroundColor Yellow
	Start-Sleep -Seconds 3

	# Iterate through the servers and call the functions
	foreach ($server in $serverListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$cpu = Get-CPUMemoryUsage -Server $server
		Write-Output "Performance status of $server :" $cpu
	}

	Write-Host "`n"
	Write-Host "############################### Service Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the services..." -ForegroundColor Cyan
	Start-Sleep -Seconds 3

	# Iterate through the servers and call the functions
	foreach ($server in $serverListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$service = Get-AllServicesStatus -Server $server
		Write-Output "Services status of $server :" $service
	}

	Write-Host "`n"
	Write-Host "############################### Update Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the System information..." -ForegroundColor Cyan
	Write-Host "`n"
	Start-Sleep -Seconds 3

	foreach ($server in $serverListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$getuptodate = Get-UpToDate -Server $server
		Write-Output "System information of $server :" $getuptodate
	}


	Write-Host "`n"
	Write-Host "############################### Application Pools Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the IIS Application Pools status..." -ForegroundColor Cyan
	Write-Host "`n"
	Start-Sleep -Seconds 3

	foreach ($server in $APPpoolListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$apppool = Get-APPApplicationPoolStatus -Server $server -APPpoolListPath $APPpoolListPath
		Write-Output "Application Pool status of $server :" $apppool
	}

	foreach ($server in $WEBpoolListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$WEBapppool = Get-WEBApplicationPoolStatus -Server $server -WEBpoolListPath $WEBpoolListPath
		Write-Output "Application Pool status of $server :" $WEBapppool
	}

	Write-Host "`n"
	Write-Host "############################### IIS Sites & Bindings Status ############################### " -ForegroundColor Magenta
	Write-Host "`n"
	Write-Host "Please wait while computing the IIS Sites status..." -ForegroundColor Cyan
	Write-Host "`n"
	Start-Sleep -Seconds 3

	foreach ($server in $APPsiteListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$APPsite = Get-APPIISSiteStatus -Server $server -APPsiteListPath $APPsiteListPath
		Write-Output "IIS Sites status of $server :" $APPsite
	}

	foreach ($server in $WEBsiteListPath) {
		Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
		$WEBsite = Get-WEBIISSiteStatus -Server $server -WEBsiteListPath $WEBsiteListPath
		Write-Output "IIS Sites status of $server :" $WEBsite
	}

	Start-Sleep -Seconds 3
	Write-Host "Server Testing of" $WorkstationName "is 100% Complete. If you have any doubts, you can check the log file on" $logFile -ForegroundColor Cyan
	Stop-Transcript -Verbose

	Read-Host "Press any key to exit..."
}