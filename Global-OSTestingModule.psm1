function Get-SystemUptime {
    param(
        [string]$server
    )

    try {
        $operatingSystem = Invoke-Command -ComputerName $server -ErrorAction Stop { Get-CimInstance -ClassName Win32_OperatingSystem }
        $lastBootUpTime = $operatingSystem.LastBootUpTime
        Write-Host "Boot Date-Time of $server: $lastBootUpTime" -ForegroundColor Cyan
    }
    catch {
        Write-Host "ERROR: Failed to retrieve uptime for $server - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-DiskSpace {
    param (
        [string]$server
    )

    try {
        $percentWarning = 30
        $percentCritical = 10

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

            if ($percentFree -lt $percentCritical) {
                Write-Host "CRITICAL - $server $deviceID $volName Percentage used space = $($full - $percentFree)%" -ForegroundColor Red
            }
            elseif ($percentFree -lt $percentWarning) {
                Write-Host "WARNING - $server $deviceID $volName Percentage used space = $($full - $percentFree)%" -ForegroundColor Yellow
            }
            else {
                Write-Host "OK - $server $deviceID $volName Percentage used space = $($full - $percentFree)%" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Host "ERROR: Failed to retrieve disk space for $server - $($_.Exception.Message)" -ForegroundColor Red
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
        $outputCPU = New-Object PSObject -Property @{
            AverageCpu  = $avg
            MemoryUsage = $mem
            PercentFree = $free
        }
        return $outputCPU
    }
    catch {
        Write-Host "ERROR: Failed to retrieve CPU/Memory usage for $server - $($_.Exception.Message)" -ForegroundColor Red
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
                Invoke-Command -ComputerName $server -ErrorAction Stop { Start-Service -Name $args[0] } -ArgumentList $serviceName
                $statusMessage = "WARNING - $serviceName was Stopped and has been started."
            }

            $output += $statusMessage
        }

        return $output
    }
    catch {
        if ($_.Exception.FullyQualifiedErrorId -like "*NoServiceFoundForGivenName*") {
            return "WARNING - No services found on $server."
        }
        else {
            return "ERROR: Failed to retrieve or start services on $server - $($_.Exception.Message)"
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
                "Windows Product Name" = $windowsProductName
                "Windows Version"      = $windowsVersion
                "Windows Build"        = $windowsBuild
                "Architecture"         = $windowsArchitecture
            }
        }
        Write-Output $output
    }
    catch {
        Write-Host "ERROR: Failed to retrieve system information for $server - $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Get-APPApplicationPoolStatus {
    param(
        [string]$APPpoolListPath = "$psISE.CurrentFile.FullPath\APPPoolList.txt",
        [string]$server
    )

    try {
        $poolList = Get-Content $APPpoolListPath -ErrorAction Stop
        Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $poolList = $args[0]
            foreach ($appool in $poolList) {
                $appStatus = Get-IISAppPool -Name $appool
                if ($appStatus.State -eq "Started") {
                    Write-Host "OK - $($appStatus.Name) is $($appStatus.State)" -ForegroundColor Green
                }
                elseif ($appStatus.State -eq "Stopped") {
                    Write-Host "ERROR - $($appStatus.Name) is $($appStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                    Write-Host "`n"
                    Write-Host "Some Appools described above are not Started. We will try to start the stopped ones." -BackgroundColor Black -ForegroundColor Red
                    Start-Sleep -Seconds 5
                    Write-Host "`n"
                    Write-Host "Starting..." -ForegroundColor Yellow
                    Start-WebAppPool $appool
                    Start-Sleep -Seconds 10
                    $appStatus = Get-IISAppPool -Name $appool
                    Write-Host "Checking..." -ForegroundColor Yellow
                    Write-Host "$($appStatus.Name) is $($appStatus.State)" -ForegroundColor (if ($appStatus.State -eq "Started") { "Green" } else { "Red" })
                }
            }
        } -ArgumentList $poolList
    }
    catch {
        Write-Host "ERROR: Failed to retrieve or manage APP pools on $server - $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    }
}

function Get-WEBApplicationPoolStatus {
    param(
        [string]$WEBpoolListPath = "$psISE.CurrentFile.FullPath\WEBPoolList.txt",
        [string]$server
    )

    try {
        $poolList = Get-Content $WEBpoolListPath -ErrorAction Stop
        Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $poolList = $args[0]
            foreach ($appool in $poolList) {
                $appStatus = Get-IISAppPool -Name $appool
                if ($appStatus.State -eq "Started") {
                    Write-Host "OK - $($appStatus.Name) is $($appStatus.State)" -ForegroundColor Green
                }
                elseif ($appStatus.State -eq "Stopped") {
                    Write-Host "ERROR - $($appStatus.Name) is $($appStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                    Write-Host "`n"
                    Write-Host "Some Appools described above are not Started. We will try to start the stopped ones." -BackgroundColor Black -ForegroundColor Red
                    Start-Sleep -Seconds 5
                    Write-Host "`n"
                    Write-Host "Starting..." -ForegroundColor Yellow
                    Start-WebAppPool $appool
                    Start-Sleep -Seconds 10
                    $appStatus = Get-IISAppPool -Name $appool
                    Write-Host "Checking..." -ForegroundColor Yellow
                    Write-Host "$($appStatus.Name) is $($appStatus.State)" -ForegroundColor (if ($appStatus.State -eq "Started") { "Green" } else { "Red" })
                }
            }
        } -ArgumentList $poolList
    }
    catch {
        Write-Host "ERROR: Failed to retrieve or manage WEB pools on $server - $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    }
}

function Get-WEBIISSiteStatus {
    param(
        [string]$WEBsiteListPath = "$psISE.CurrentFile.FullPath\WEBSiteList.txt",
        [string]$server
    )

    try {
        $siteList = Get-Content $WEBsiteListPath -ErrorAction Stop
        Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $siteList = $args[0]
            foreach ($site in $siteList) {
                $siteStatus = Get-IISSite -Name $site
                if ($siteStatus.State -eq "Started") {
                    Write-Host "OK - $($siteStatus.Name) is $($siteStatus.State)" -ForegroundColor Green
                }
                elseif ($siteStatus.State -eq "Stopped") {
                    Write-Host "ERROR - $($siteStatus.Name) is $($siteStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                }
            }
        } -ArgumentList $siteList
    }
    catch {
        Write-Host "ERROR: Failed to retrieve WEB site status on $server - $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    }
}

function Get-APPIISSiteStatus {
    param(
        [string]$APPsiteListPath = "$psISE.CurrentFile.FullPath\APPSiteList.txt",
        [string]$server
    )

    try {
        $siteList = Get-Content $APPsiteListPath -ErrorAction Stop
        Invoke-Command -ComputerName $server -ErrorAction Stop {
            Import-Module WebAdministration
            $siteList = $args[0]
            foreach ($site in $siteList) {
                $siteStatus = Get-IISSite -Name $site
                if ($siteStatus.State -eq "Started") {
                    Write-Host "OK - $($siteStatus.Name) is $($siteStatus.State)" -ForegroundColor Green
                }
                elseif ($siteStatus.State -eq "Stopped") {
                    Write-Host "ERROR - $($siteStatus.Name) is $($siteStatus.State)" -BackgroundColor Black -ForegroundColor Yellow
                }
            }
        } -ArgumentList $siteList
    }
    catch {
        Write-Host "ERROR: Failed to retrieve APP site status on $server - $($_.Exception.Message)" -BackgroundColor Black -ForegroundColor Red
    }
}