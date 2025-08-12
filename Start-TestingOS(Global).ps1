function Start-TestingOS {
    <#
    .Synopsis
       Script for performing basic testing on Multiple Windows Servers.
    .DESCRIPTION
       The script contains the following functions:
       1. Read and check the status of all services
       2. Check the UpTime of the server to see if the server was rebooted correctly
       3. Check the disk space of the server
       4. Check the performance of the server
       5. Check the version, build, and name of the system installed
       6. Check the following on the IIS:
           Check if the Application Pools are "Started" (In App & Web)
           Check if the IIS Sites are "Started" (In App & Web)

    .PARAMETER ServerListPath
        Path to the file containing the list of servers for general checks
    .PARAMETER APPServerListPath
        Path to the file containing the list of APP servers
    .PARAMETER WEBServerListPath
        Path to the file containing the list of WEB servers
    .PARAMETER APPpoolListPath
        Path to the file containing the App Pool List for APP servers
    .PARAMETER WEBpoolListPath
        Path to the file containing the App Pool List for WEB servers
    .PARAMETER APPsiteListPath
        Path to the file containing the IIS site List for APP servers
    .PARAMETER WEBsiteListPath
        Path to the file containing the IIS site List for WEB servers

    .EXAMPLE
        Start-TestingOS -ServerListPath ".\ServerList.txt" -APPServerListPath ".\APPServerList.txt" -WEBServerListPath ".\WEBServerList.txt" -APPpoolListPath ".\APPPoolList.txt" -WEBpoolListPath ".\WEBPoolList.txt" -APPsiteListPath ".\APPSiteList.txt" -WEBsiteListPath ".\WEBSiteList.txt"
    #>
    param(
        [string]$ServerListPath = "$psISE.CurrentFile.FullPath\ServerList.txt",
        [string]$APPServerListPath = "$psISE.CurrentFile.FullPath\APPServerList.txt",
        [string]$WEBServerListPath = "$psISE.CurrentFile.FullPath\WEBServerList.txt",
        [string]$APPpoolListPath = "$psISE.CurrentFile.FullPath\APPPoolList.txt",
        [string]$WEBpoolListPath = "$psISE.CurrentFile.FullPath\WEBPoolList.txt",
        [string]$APPsiteListPath = "$psISE.CurrentFile.FullPath\APPSiteList.txt",
        [string]$WEBsiteListPath = "$psISE.CurrentFile.FullPath\WEBSiteList.txt"
    )

    # Validate input files
    $files = @($ServerListPath, $APPServerListPath, $WEBServerListPath, $APPpoolListPath, $WEBpoolListPath, $APPsiteListPath, $WEBsiteListPath)
    foreach ($file in $files) {
        if (-not (Test-Path $file)) {
            Write-Host "ERROR: File $file not found. Please ensure all required files exist." -ForegroundColor Red
            return
        }
    }

    # Start logging
    $logFile = "$psISE.CurrentFile.FullPath\PostOSTesting $(Get-Date -Format yyyy-MM-dd).txt"
    Start-Transcript $logFile -Append -IncludeInvocationHeader

    ############################ Define Server & Services Variable ###############
    $CurrentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $WorkstationName = [System.Net.Dns]::GetHostName()
    $servers = Get-Content $ServerListPath
    $APPServers = Get-Content $APPServerListPath
    $WEBServers = Get-Content $WEBServerListPath
    Import-Module PSWindowsUpdate

    Write-Host "Welcome $CurrentUserName"
    Write-Host "############################### System Uptime Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the details..." -ForegroundColor Cyan

    # Iterate through the servers and call the functions
    foreach ($server in $servers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $systemUptime = Get-SystemUptime -Server $server
        Write-Output "Last Boot Uptime of $server :" $systemUptime
    }

    Write-Host "############################### Disk Status ###############################" -ForegroundColor Magenta
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
    foreach ($server in $servers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $disk = Get-DiskSpace -Server $server
        Write-Output "Disks status of $server :" $disk
    }

    Write-Host "`n"
    Write-Host "############################### CPU & Memory Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the CPU & Memory Performance..." -ForegroundColor Cyan
    Write-Host "--------------------------------" -ForegroundColor Cyan
    Write-Host "NOTE: The below values are expressed in % (Percentage)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3

    # Iterate through the servers and call the functions
    foreach ($server in $servers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $cpu = Get-CPUMemoryUsage -Server $server
        Write-Output "Performance status of $server :" $cpu
    }

    Write-Host "`n"
    Write-Host "############################### Service Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the services..." -ForegroundColor Cyan
    Start-Sleep -Seconds 3

    # Iterate through the servers and call the functions
    foreach ($server in $servers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $service = Get-AllServicesStatus -Server $server
        Write-Output "Services status of $server :" $service
    }

    Write-Host "`n"
    Write-Host "############################### Update Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the System information..." -ForegroundColor Cyan
    Write-Host "`n"
    Start-Sleep -Seconds 3

    foreach ($server in $servers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $getuptodate = Get-UpToDate -Server $server
        Write-Output "System information of $server :" $getuptodate
    }

    Write-Host "`n"
    Write-Host "############################### Application Pools Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the IIS Application Pools status..." -ForegroundColor Cyan
    Write-Host "`n"
    Start-Sleep -Seconds 3

    foreach ($server in $APPServers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $apppool = Get-APPApplicationPoolStatus -Server $server -APPpoolListPath $APPpoolListPath
        Write-Output "Application Pool status of $server :" $apppool
    }

    foreach ($server in $WEBServers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $WEBapppool = Get-WEBApplicationPoolStatus -Server $server -WEBpoolListPath $WEBpoolListPath
        Write-Output "Application Pool status of $server :" $WEBapppool
    }

    Write-Host "`n"
    Write-Host "############################### IIS Sites & Bindings Status ###############################" -ForegroundColor Magenta
    Write-Host "`n"
    Write-Host "Please wait while computing the IIS Sites status..." -ForegroundColor Cyan
    Write-Host "`n"
    Start-Sleep -Seconds 3

    foreach ($server in $APPServers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $APPsite = Get-APPIISSiteStatus -Server $server -APPsiteListPath $APPsiteListPath
        Write-Output "IIS Sites status of $server :" $APPsite
    }

    foreach ($server in $WEBServers) {
        Write-Host "Obtaining details from $server ..." -ForegroundColor Cyan
        $WEBsite = Get-WEBIISSiteStatus -Server $server -WEBsiteListPath $WEBsiteListPath
        Write-Output "IIS Sites status of $server :" $WEBsite
    }

    Start-Sleep -Seconds 3
    Write-Host "Server Testing of $WorkstationName is 100% Complete. If you have any doubts, you can check the log file on $logFile" -ForegroundColor Cyan
    Stop-Transcript -Verbose

    Read-Host "Press any key to exit..."
}