function Start-TestingOS {
    <#
    .Synopsis
       Script for performing basic testing on Weekends post OS Patching
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

    try {
        # Validate input files
        $files = @($ServerListPath, $APPServerListPath, $WEBServerListPath, $APPpoolListPath, $WEBpoolListPath, $APPsiteListPath, $WEBsiteListPath)
        foreach ($file in $files) {
            if (-not (Test-Path $file)) {
                Write-Error "File $file not found. Please ensure all required files exist."
                return
            }
        }

        # Start logging
        $logFile = "$psISE.CurrentFile.FullPath\PostOSTesting $(Get-Date -Format yyyy-MM-dd).txt"
        Start-Transcript $logFile -Append -IncludeInvocationHeader -ErrorAction Stop

        # Initialize results collection
        $results = [pscustomobject]@{
            SystemUptime = @()
            DiskStatus = @()
            CPUMemoryUsage = @()
            ServiceStatus = @()
            UpdateStatus = @()
            APPPoolStatus = @()
            WEBPoolStatus = @()
            APPSiteStatus = @()
            WEBSiteStatus = @()
        }

        # Define variables
        $CurrentUserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $WorkstationName = [System.Net.Dns]::GetHostName()
        $servers = Get-Content $ServerListPath -ErrorAction Stop
        $APPServers = Get-Content $APPServerListPath -ErrorAction Stop
        $WEBServers = Get-Content $WEBServerListPath -ErrorAction Stop

        # Import module
        try {
            Import-Module .\Global-OSTestingModule.psm1 -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to import Global-OSTestingModule.psm1 - $($_.Exception.Message)"
            return
        }

        Write-Host "Welcome $CurrentUserName" -ForegroundColor Cyan
        Write-Host "############################### System Uptime Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the details..." -ForegroundColor Cyan

        # System Uptime
        foreach ($server in $servers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping uptime check."
                $results.SystemUptime += [pscustomobject]@{
                    Server = $server
                    LastBootUpTime = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining uptime details from $server ..." -ForegroundColor Cyan
            $results.SystemUptime += Get-SystemUptime -Server $server
        }

        Write-Host "############################### Disk Status ###############################" -ForegroundColor Magenta
        Write-Host "Color Coding" -ForegroundColor Cyan
        Write-Host "------------------------" -ForegroundColor Cyan
        Write-Host "WARNING: More than 75% used" -ForegroundColor Yellow
        Write-Host "CRITICAL: More than 90% used" -ForegroundColor Red
        Write-Host "OK: Less than 75% used" -ForegroundColor Green
        Write-Host "`nPlease wait while computing the Disks details..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        # Disk Status
        foreach ($server in $servers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping disk check."
                $results.DiskStatus += [pscustomobject]@{
                    Server = $server
                    DeviceID = $null
                    VolumeName = $null
                    SizeGB = $null
                    FreeSpaceGB = $null
                    PercentFree = $null
                    Status = "ERROR"
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining disk details from $server ..." -ForegroundColor Cyan
            $results.DiskStatus += Get-DiskSpace -Server $server
        }

        Write-Host "`n############################### CPU & Memory Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the CPU & Memory Performance..." -ForegroundColor Cyan
        Write-Host "--------------------------------" -ForegroundColor Cyan
        Write-Host "NOTE: The below values are expressed in % (Percentage)" -ForegroundColor Yellow
        Start-Sleep -Seconds 3

        # CPU & Memory Usage
        foreach ($server in $servers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping CPU/memory check."
                $results.CPUMemoryUsage += [pscustomobject]@{
                    Server = $server
                    AverageCpu = $null
                    MemoryUsage = $null
                    PercentFreeDisk = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining performance details from $server ..." -ForegroundColor Cyan
            $results.CPUMemoryUsage += Get-CPUMemoryUsage -Server $server
        }

        Write-Host "`n############################### Service Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the services..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        # Service Status
        foreach ($server in $servers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping service check."
                $results.ServiceStatus += [pscustomobject]@{
                    Server = $server
                    ServiceName = $null
                    Status = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining service details from $server ..." -ForegroundColor Cyan
            $results.ServiceStatus += Get-AllServicesStatus -Server $server
        }

        Write-Host "`n############################### Update Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the System information..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        # Update Status
        foreach ($server in $servers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping update check."
                $results.UpdateStatus += [pscustomobject]@{
                    Server = $server
                    WindowsProductName = $null
                    WindowsVersion = $null
                    WindowsBuild = $null
                    Architecture = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining system info from $server ..." -ForegroundColor Cyan
            $results.UpdateStatus += Get-UpToDate -Server $server
        }

        Write-Host "`n############################### Application Pools Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the IIS Application Pools status..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        # APP Application Pools
        foreach ($server in $APPServers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping APP pool check."
                $results.APPPoolStatus += [pscustomobject]@{
                    Server = $server
                    PoolName = $null
                    State = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining APP pool details from $server ..." -ForegroundColor Cyan
            $results.APPPoolStatus += Get-APPApplicationPoolStatus -Server $server -APPpoolListPath $APPpoolListPath
        }

        # WEB Application Pools
        foreach ($server in $WEBServers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping WEB pool check."
                $results.WEBPoolStatus += [pscustomobject]@{
                    Server = $server
                    PoolName = $null
                    State = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining WEB pool details from $server ..." -ForegroundColor Cyan
            $results.WEBPoolStatus += Get-WEBApplicationPoolStatus -Server $server -WEBpoolListPath $WEBpoolListPath
        }

        Write-Host "`n############################### IIS Sites & Bindings Status ###############################" -ForegroundColor Magenta
        Write-Host "`nPlease wait while computing the IIS Sites status..." -ForegroundColor Cyan
        Start-Sleep -Seconds 3

        # APP IIS Sites
        foreach ($server in $APPServers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping APP site check."
                $results.APPSiteStatus += [pscustomobject]@{
                    Server = $server
                    SiteName = $null
                    State = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining APP site details from $server ..." -ForegroundColor Cyan
            $results.APPSiteStatus += Get-APPIISSiteStatus -Server $server -APPsiteListPath $APPsiteListPath
        }

        # WEB IIS Sites
        foreach ($server in $WEBServers) {
            if (-not (Test-Connection -ComputerName $server -Count 1 -Quiet)) {
                Write-Error "Cannot connect to $server. Skipping WEB site check."
                $results.WEBSiteStatus += [pscustomobject]@{
                    Server = $server
                    SiteName = $null
                    State = $null
                    StatusMessage = "ERROR: Cannot connect to $server"
                }
                continue
            }
            Write-Host "Obtaining WEB site details from $server ..." -ForegroundColor Cyan
            $results.WEBSiteStatus += Get-WEBIISSiteStatus -Server $server -WEBsiteListPath $WEBsiteListPath
        }

        Write-Host "Server Testing of $WorkstationName is 100% Complete. If you have any doubts, you can check the log file on $logFile" -ForegroundColor Cyan
        Write-Output $results
    }
    catch {
        Write-Error "Script execution failed: $($_.Exception.Message)"
        return [pscustomobject]@{
            SystemUptime = $null
            DiskStatus = $null
            CPUMemoryUsage = $null
            ServiceStatus = $null
            UpdateStatus = $null
            APPPoolStatus = $null
            WEBPoolStatus = $null
            APPSiteStatus = $null
            WEBSiteStatus = $null
            StatusMessage = "ERROR: Script execution failed - $($_.Exception.Message)"
        }
    }
    finally {
        Stop-Transcript -ErrorAction SilentlyContinue
        Read-Host "Press any key to exit..."
    }
}