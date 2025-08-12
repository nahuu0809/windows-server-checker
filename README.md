# 🔧 PowerShell Post-OS Patching Testing Suite

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)
![Windows](https://img.shields.io/badge/Platform-Windows-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Status](https://img.shields.io/badge/Status-Active-brightgreen.svg)

## 📋 Overview

A comprehensive PowerShell testing suite designed for Windows servers. This toolkit helps system administrators to quickly verify system health, performance, and IIS functionality after applying operating system patches during maintenance windows.

## ✨ Features

### 🖥️ **System Health Monitoring**
- ⏱️ **System Uptime Checking** - Verify successful reboots after patching
- 💾 **Disk Space Analysis** - Monitor storage usage with colored alerts
- 🔄 **CPU & Memory Performance** - Resource utilization tracking
- 🛠️ **Windows Service Status** - Comprehensive service health validation

### 🌐 **IIS Web Server Support**
- 🏊 **Application Pool Monitoring** - Automated pool status checking and recovery
- 🌍 **IIS Site Status Validation** - Ensure web applications are running
- 📱 **APP & WEB Server Differentiation** - Separate monitoring for different server roles

### 📊 **System Information**
- 🔍 **OS Version & Build Information** - Track system patch levels
- 📝 **Automated Logging** - Complete audit trails with timestamped logs
- 🎨 **Color-Coded Output** - Visual status indicators for quick assessment

## 🚀 Quick Start

### Prerequisites

- 🖥️ **Windows PowerShell 5.1+** or **PowerShell Core 7+**
- 👤 **Administrative privileges** on target servers
- 🌐 **WinRM enabled** for remote server management
- 📦 **IIS Management Tools** (for web server monitoring)

### 📂 File Structure

```
📁 PowerShell-Post-Patching-Suite/
├── 📄 Global-OSTestingModule.psm1    # Core testing functions
├── 📄 Start-TestingOS(Global).ps1    # Main execution script
├── 📄 ServerList.txt                 # List of servers to test
├── 📄 APPPoolList.txt               # Application server pools
├── 📄 WEBPoolList.txt               # Web server pools
├── 📄 APPSiteList.txt               # Application server sites
├── 📄 WEBSiteList.txt               # Web server sites
└── 📄 README.md                     # This file
```

### 🔧 Installation

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/nahuu0809/windows-server-checker.git
   cd windows-server-checker
   ```

2. **Configure your environment:**
   - Edit `ServerList.txt` with your server names
   - Update pool and site list files as needed
   - Ensure proper network connectivity to target servers

3. **Run the testing suite:**
   ```powershell
   .\Start-TestingOS(Global).ps1
   ```

## 📖 Usage Examples

### 🎯 Individual Function Usage

```powershell
# Import the module
Import-Module .\Global-OSTestingModule.psm1

# Check system uptime
Get-SystemUptime -server "SERVER01"

# Monitor disk space
Get-DiskSpace -server "SERVER01"

# Check CPU and memory usage
Get-CPUMemoryUsage -server "SERVER01"

# Validate all services
Get-AllServicesStatus -server "SERVER01"
```

### 🔄 Full Automated Testing

```powershell
# Run complete post-patching validation
Start-TestingOS
```

## 🎨 Output Examples

### ✅ Successful Disk Check
```
OK - SERVER01 C: System Percentage used space = 45.67%
```

### ⚠️ Warning Conditions
```
WARNING - SERVER02 D: Data Percentage used space = 78.23%
```

### ❌ Critical Issues
```
CRITICAL - SERVER03 E: Logs Percentage used space = 92.15%
```

## 📋 Configuration Files

### 📄 ServerList.txt
```
SERVER01
SERVER02
SERVER03
WEBSERVER01
APPSERVER01
```

### 📄 APPPoolList.txt
```
DefaultAppPool
MyApplication
APIServices
```

## ⚙️ Advanced Configuration

### 🎚️ Disk Space Thresholds
Currently configured in the module:
- ⚠️ **Warning**: 70% used (30% free)
- ❌ **Critical**: 90% used (10% free)

### 📝 Logging
Logs are automatically saved to:
```
PostOSTesting YYYY-MM-DD.txt
```

## 🔍 Functions Reference

| Function | Purpose | Parameters |
|----------|---------|------------|
| `Get-SystemUptime` | 📅 Check last boot time | `-server` |
| `Get-DiskSpace` | 💾 Monitor disk usage | `-server` |
| `Get-CPUMemoryUsage` | 📊 Performance metrics | `-server` |
| `Get-AllServicesStatus` | 🛠️ Service validation | `-server` |
| `Get-UpToDate` | 🔍 OS version info | `-server` |
| `Get-APPApplicationPoolStatus` | 🏊 APP pool monitoring | `-server`, `-APPpoolListPath` |
| `Get-WEBApplicationPoolStatus` | 🌐 WEB pool monitoring | `-server`, `-WEBpoolListPath` |

## ⚠️ IMPORTANT NOTES ⚠️

- 🔒 **Service Management**: The script automatically attempts to start stopped services
- 🌐 **Remote Access**: Ensure WinRM is properly configured for remote server access
- 👤 **Permissions**: Run with appropriate administrative credentials
- 📝 **Logging**: All operations are logged with timestamps for audit purposes


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


## 🏷️ Tags

`powershell` `windows-server` `system-administration` `monitoring` `iis` `post-patching` `automation` `devops` `infrastructure`

---

Made with ❤️ for the Windows Server community