function Get-SystemUptime {
    param(
        [string]$server
    )

    try {
        $operatingSystem = Invoke-Command -ComputerName $server -ErrorAction Stop { Get-CimInstance -ClassName Win32_OperatingSystem }
        $lastBootUpTime = $operatingSystem.LastBootUpTime
        Write-Output [pscustomobject]@{
            Server = $server
            LastBootUpTime = $lastBootUpTime
            StatusMessage = "Boot Date/Time of $server: $lastBootUpTime"
        }
    }
    catch {
        Write-Error "Failed to retrieve uptime for $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            LastBootUpTime = $null
            StatusMessage = "ERROR: Failed to retrieve uptime - $($_.Exception.Message)"
        }
    }
}

function Get-DiskSpace {
    param (
        [string]$server
    )

    try {
        $percentWarning = 30
        $percentCritical = 10
        $results = @()

        $disks = Invoke-Command -ComputerName $server -ErrorAction Stop { Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" }
        foreach ($disk in $disks) {
            $deviceID = $disk.DeviceID
            $volName = $disk.VolumeName
            [float]$size = $disk.Size
            [float]$freeSpace = $disk.FreeSpace
            $percentFree = [math]::Round(($freeSpace / $size) * 100, 2)
            $sizeGB = [math]::Round($size / 1073741824, 2)
            $freeSpaceGB = [math]::Round($freeSpace / 1073741824, 2)
            $usedSpaceGB = $sizeGB - $freeSpaceGB
            $full = 100

            $status = if ($percentFree -lt $percentCritical) { "CRITICAL" }
                      elseif ($percentFree -lt $percentWarning) { "WARNING" }
                      else { "OK" }
            $statusMessage = "$status - $server $deviceID $volName Percentage used space = $($full - $percentFree)%"

            $results += [pscustomobject]@{
                Server = $server
                DeviceID = $deviceID
                VolumeName = $volName
                SizeGB = $sizeGB
                FreeSpaceGB = $freeSpaceGB
                PercentFree = $percentFree
                Status = $status
                StatusMessage = $statusMessage
            }
        }
        Write-Output $results
    }
    catch {
        Write-Error "Failed to retrieve disk space for $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            DeviceID = $null
            VolumeName = $null
            SizeGB = $null
            FreeSpaceGB = $null
            PercentFree = $null
            Status = "ERROR"
            StatusMessage = "ERROR: Failed to retrieve disk space - $($_.Exception.Message)"
        }
    }
}

function Get-CPUMemoryUsage {
    param(
        [string]$server
    )

    try {
        $avg = Invoke-Command -ComputerName $server -ErrorAction Stop {
            $cpu = Get-WmiObject win32_processor
            Measure-Object -InputObject $cpu -Property LoadPercentage -Average | ForEach-Object { $_.Average }
        }
        $os = Invoke-Command -ComputerName $server -ErrorAction Stop { Get-WmiObject win32_operatingsystem }
        $mem = "{0:N2}" -f ((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 100) / $os.TotalVisibleMemorySize)
        $free = Invoke-Command -ComputerName $server -ErrorAction Stop {
            $volume = Get-WmiObject Win32_Volume -Filter "DriveLetter = 'C:'"
            "{0:N2}" -f (($volume.FreeSpace / $volume.Capacity) * 100)
        }
        $outputCPU = [pscustomobject]@{
            Server = $server
            AverageCpu = $avg
            MemoryUsage = $mem
            PercentFreeDisk = $free
            StatusMessage = "Performance for $server: CPU=$avg%, Memory=$mem%, C: Free=$free%"
        }
        Write-Output $outputCPU
    }
    catch {
        Write-Error "Failed to retrieve CPU/Memory usage for $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            AverageCpu = $null
            MemoryUsage = $null
            PercentFreeDisk = $null
            StatusMessage = "ERROR: Failed to retrieve CPU/Memory usage - $($_.Exception.Message)"
        }
    }
}

function Get-AllServicesStatus {
    param (
        [string]$server
    )

    try {
        $services = Invoke-Command -ComputerName $server -ErrorAction Stop {
            Get-Service
        }
        $output = @()

        foreach ($service in $services) {
            $serviceName = $service.Name
            $status = $service.Status

            if ($status -eq "Running") {
                $statusMessage = "OK - $serviceName is $status"
            }
            elseif ($status -eq "Stopped") {
                try {
                    Invoke-Command -ComputerName $server -ErrorAction Stop { Start-Service -Name $args[0] } -ArgumentList $serviceName
                    $statusMessage = "WARNING - $serviceName was Stopped and has been started."
                }
                catch {
                    $statusMessage = "ERROR - $serviceName was Stopped and failed to start: $($_.Exception.Message)"
                }
            }
            else {
                $statusMessage = "WARNING - $serviceName is $status"
            }

            $output += [pscustomobject]@{
                Server = $server
                ServiceName = $serviceName
                Status = $status
                StatusMessage = $statusMessage
            }
        }

        Write-Output $output
    }
    catch {
        Write-Error "Failed to retrieve or manage services on $server - $($_.Exception.Message)"
        if ($_.Exception.FullyQualifiedErrorId -like "*NoServiceFoundForGivenName*") {
            return [pscustomobject]@{
                Server = $server
                ServiceName = $null
                Status = $null
                StatusMessage = "WARNING - No services found on $server."
            }
        }
        return [pscustomobject]@{
            Server = $server
            ServiceName = $null
            Status = $null
            StatusMessage = "ERROR: Failed to retrieve or manage services - $($_.Exception.Message)"
        }
    }
}

function Get-UpToDate {
    param(
        [string]$server
    )

    try {
        $output = Invoke-Command -ComputerName $server -ErrorAction Stop {
            $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
            $regKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"

            $windowsVersion = $regKey.ReleaseID
            $windowsBuild = ($regKey.BuildLabEx -match '^[0-9]+\.[0-9]+') | ForEach-Object { $matches.Values }
            $windowsProductName = $osInfo.Caption
            $windowsArchitecture = $osInfo.OSArchitecture

            [pscustomobject]@{
                Server = $args[0]
                WindowsProductName = $windowsProductName
                WindowsVersion = $windowsVersion
                WindowsBuild = $windowsBuild
                Architecture = $windowsArchitecture
                StatusMessage = "System info for $args[0]: $windowsProductName, Version=$windowsVersion, Build=$windowsBuild, Arch=$windowsArchitecture"
            }
        } -ArgumentList $server
        Write-Output $output
    }
    catch {
        Write-Error "Failed to retrieve system information for $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            WindowsProductName = $null
            WindowsVersion = $null
            WindowsBuild = $null
            Architecture = $null
            StatusMessage = "ERROR: Failed to retrieve system information - $($_.Exception.Message)"
        }
    }
}

function Get-APPApplicationPoolStatus {
    param(
        [string]$APPpoolListPath = "$psISE.CurrentFile.FullPath\APPPoolList.txt",
        [string]$server
    )

    try {
        $poolList = Get-Content $APPpoolListPath -ErrorAction Stop
        $results = Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $poolList = $args[0]
            $results = @()
            foreach ($appool in $poolList) {
                try {
                    $appStatus = Get-IISAppPool -Name $appool
                    $statusMessage = if ($appStatus.State -eq "Started") {
                        Write-Host "OK - $($appStatus.Name) is $($appStatus.State)" -ForegroundColor Green
                        "OK - $($appStatus.Name) is $($appStatus.State)"
                    }
                    else {
                        Write-Host "ERROR - $($appStatus.Name) is $($appStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                        Write-Host "`nSome Appools described above are not Started. We will try to start the stopped ones." -BackgroundColor Black -ForegroundColor Red
                        Start-Sleep -Seconds 5
                        Write-Host "`nStarting..." -ForegroundColor Yellow
                        Start-WebAppPool $appool
                        Start-Sleep -Seconds 10
                        $appStatus = Get-IISAppPool -Name $appool
                        Write-Host "Checking..." -ForegroundColor Yellow
                        $color = if ($appStatus.State -eq "Started") { "Green" } else { "Red" }
                        Write-Host "$($appStatus.Name) is $($appStatus.State)" -ForegroundColor $color
                        if ($appStatus.State -eq "Started") { "OK - $($appStatus.Name) is $($appStatus.State) after restart" }
                        else { "ERROR - $($appStatus.Name) is $($appStatus.State) after restart attempt" }
                    }
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        PoolName = $appStatus.Name
                        State = $appStatus.State
                        StatusMessage = $statusMessage
                    }
                }
                catch {
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        PoolName = $appool
                        State = $null
                        StatusMessage = "ERROR - Failed to check or start $appool: $($_.Exception.Message)"
                    }
                }
            }
            return $results
        } -ArgumentList $poolList, $server
        Write-Output $results
    }
    catch {
        Write-Error "Failed to retrieve or manage APP pools on $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            PoolName = $null
            State = $null
            StatusMessage = "ERROR: Failed to retrieve or manage APP pools - $($_.Exception.Message)"
        }
    }
}

function Get-WEBApplicationPoolStatus {
    param(
        [string]$WEBpoolListPath = "$psISE.CurrentFile.FullPath\WEBPoolList.txt",
        [string]$server
    )

    try {
        $poolList = Get-Content $WEBpoolListPath -ErrorAction Stop
        $results = Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $poolList = $args[0]
            $results = @()
            foreach ($appool in $poolList) {
                try {
                    $appStatus = Get-IISAppPool -Name $appool
                    $statusMessage = if ($appStatus.State -eq "Started") {
                        Write-Host "OK - $($appStatus.Name) is $($appStatus.State)" -ForegroundColor Green
                        "OK - $($appStatus.Name) is $($appStatus.State)"
                    }
                    else {
                        Write-Host "ERROR - $($appStatus.Name) is $($appStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                        Write-Host "`nSome Appools described above are not Started. We will try to start the stopped ones." -BackgroundColor Black -ForegroundColor Red
                        Start-Sleep -Seconds 5
                        Write-Host "`nStarting..." -ForegroundColor Yellow
                        Start-WebAppPool $appool
                        Start-Sleep -Seconds 10
                        $appStatus = Get-IISAppPool -Name $appool
                        Write-Host "Checking..." -ForegroundColor Yellow
                        $color = if ($appStatus.State -eq "Started") { "Green" } else { "Red" }
                        Write-Host "$($appStatus.Name) is $($appStatus.State)" -ForegroundColor $color
                        if ($appStatus.State -eq "Started") { "OK - $($appStatus.Name) is $($appStatus.State) after restart" }
                        else { "ERROR - $($appStatus.Name) is $($appStatus.State) after restart attempt" }
                    }
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        PoolName = $appStatus.Name
                        State = $appStatus.State
                        StatusMessage = $statusMessage
                    }
                }
                catch {
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        PoolName = $appool
                        State = $null
                        StatusMessage = "ERROR - Failed to check or start $appool: $($_.Exception.Message)"
                    }
                }
            }
            return $results
        } -ArgumentList $poolList, $server
        Write-Output $results
    }
    catch {
        Write-Error "Failed to retrieve or manage WEB pools on $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            PoolName = $null
            State = $null
            StatusMessage = "ERROR: Failed to retrieve or manage WEB pools - $($_.Exception.Message)"
        }
    }
}

function Get-WEBIISSiteStatus {
    param(
        [string]$WEBsiteListPath = "$psISE.CurrentFile.FullPath\WEBSiteList.txt",
        [string]$server
    )

    try {
        $siteList = Get-Content $WEBsiteListPath -ErrorAction Stop
        $results = Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $siteList = $args[0]
            $results = @()
            foreach ($site in $siteList) {
                try {
                    $siteStatus = Get-IISSite -Name $site
                    $statusMessage = if ($siteStatus.State -eq "Started") {
                        Write-Host "OK - $($siteStatus.Name) is $($siteStatus.State)" -ForegroundColor Green
                        "OK - $($siteStatus.Name) is $($siteStatus.State)"
                    }
                    else {
                        Write-Host "ERROR - $($siteStatus.Name) is $($siteStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                        "ERROR - $($siteStatus.Name) is $($siteStatus.State)"
                    }
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        SiteName = $siteStatus.Name
                        State = $siteStatus.State
                        StatusMessage = $statusMessage
                    }
                }
                catch {
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        SiteName = $site
                        State = $null
                        StatusMessage = "ERROR - Failed to check $site: $($_.Exception.Message)"
                    }
                }
            }
            return $results
        } -ArgumentList $siteList, $server
        Write-Output $results
    }
    catch {
        Write-Error "Failed to retrieve WEB site status on $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            SiteName = $null
            State = $null
            StatusMessage = "ERROR: Failed to retrieve WEB site status - $($_.Exception.Message)"
        }
    }
}

function Get-APPIISSiteStatus {
    param(
        [string]$APPsiteListPath = "$psISE.CurrentFile.FullPath\APPSiteList.txt",
        [string]$server
    )

    try {
        $siteList = Get-Content $APPsiteListPath -ErrorAction Stop
        $results = Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $siteList = $args[0]
            $results = @()
            foreach ($site in $siteList) {
                try {
                    $siteStatus = Get-IISSite -Name $site
                    $statusMessage = if ($siteStatus.State -eq "Started") {
                        Write-Host "OK - $($siteStatus.Name) is $($siteStatus.State)" -ForegroundColor Green
                        "OK - $($siteStatus.Name) is $($siteStatus.State)"
                    }
                    else {
                        Write-Host "ERROR - $($siteStatus.Name) is $($siteStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                        "ERROR - $($siteStatus.Name) is $($siteStatus.State)"
                    }
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        SiteName = $siteStatus.Name
                        State = $siteStatus.State
                        StatusMessage = $statusMessage
                    }
                }
                catch {
                    $results += [pscustomobject]@{
                        Server = $args[1]
                        SiteName = $site
                        State = $null
                        StatusMessage = "ERROR - Failed to check $site: $($_.Exception.Message)"
                    }
                }
            }
            return $results
        } -ArgumentList $siteList, $server
        Write-Output $results
    }
    catch {
        Write-Error "Failed to retrieve APP site status on $server - $($_.Exception.Message)"
        return [pscustomobject]@{
            Server = $server
            SiteName = $null
            State = $null
            StatusMessage = "ERROR: Failed to retrieve APP site status - $($_.Exception.Message)"
        }
    }
}