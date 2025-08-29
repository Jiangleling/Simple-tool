# ===================================================================
# 安装脚本 v5 (使用XML定义，兼容性最强)
# ===================================================================

# 1. 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "此脚本需要管理员权限。"
    Read-Host "按 Enter 键退出。"
    exit
}

Clear-Host
Write-Host "--- 开始配置自动热点功能 (v5) ---" -ForegroundColor Cyan

# 2. 定义路径
$installPath = "C:\Users\Public\Documents\AutoHotspot"
$scriptName = "HotspotTrigger.ps1"
$logName = "log.txt"
$scriptFullPath = Join-Path $installPath $scriptName
$taskName = "Auto USB Hotspot Trigger"

# 3. 创建目录
try {
    Write-Host "步骤 1: 正在尝试创建目录: $installPath"
    if (-NOT (Test-Path $installPath)) {
        New-Item -Path $installPath -ItemType Directory -ErrorAction Stop | Out-Null
    }
    Write-Host "  [成功] 目录已存在或已创建。" -ForegroundColor Green
} catch {
    Write-Error "  [失败] 创建目录时发生严重错误: $($_.Exception.Message)"
    Read-Host "按 Enter 键退出。"
    exit
}

# 4. 定义核心脚本内容 (使用单引号here-string, 修复潜在的变量解析问题)
$scriptContent = @'
# 核心脚本 v5
$logFile = "C:\Users\Public\Documents\AutoHotspot\log.txt"
function Write-Log { param([string]$Message) $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; "[$timestamp] $Message" | Out-File -FilePath $logFile -Append }
Write-Log "--- 脚本开始运行 ---"
function Start-MobileHotspot {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        $tetheringManager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType=WindowsRuntime]
        $connectionProfile = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType=WindowsRuntime]::GetInternetConnectionProfile()
        if ($null -eq $connectionProfile) { Write-Log "错误：未找到可用于共享的有效网络连接。"; return }
        Write-Log "找到可共享的网络: $($connectionProfile.ProfileName)"
        $manager = $tetheringManager::CreateFromConnectionProfile($connectionProfile)
        if ($manager.TetheringOperationalState -ne 'On') {
            Write-Log "热点当前为关闭状态，正在尝试开启..."
            $startOperation = $manager.StartTetheringAsync()
            $startTask = $asTaskGeneric.MakeGenericMethod([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult]).Invoke($null, @($startOperation))
            $startResult = $startTask.GetAwaiter().GetResult()
            if ($startResult.Status -eq 'Success') { Write-Log "热点开启成功。" } else { Write-Log "热点开启失败，状态: $($startResult.Status)" }
        } else { Write-Log "热点已经是开启状态，无需操作。" }
    } catch { Write-Log "在开启热点时发生严重错误: $($_.Exception.Message)" }
}
try {
    Write-Log "正在检查网络连接..."
    $connectedProfiles = Get-NetConnectionProfile | Where-Object { $_.IPv4Connectivity -eq 'Internet' }
    if ($null -eq $connectedProfiles) { Write-Log "未找到任何处于 'Internet' 连接状态的网络适配器。" } else {
        $foundUsbDevice = $false
        foreach ($profile in $connectedProfiles) {
            $adapter = Get-NetAdapter -InterfaceIndex $profile.InterfaceIndex
            Write-Log "正在检查适配器: '$($adapter.Name)'，设备ID: '$($adapter.PnpDeviceID)'"
            if ($adapter.PnpDeviceID -like "USB*" -or $adapter.PnpDeviceID -like "*RNDIS*") {
                Write-Log "检测到符合条件的USB/RNDIS网络连接: '$($adapter.Name)'。准备开启热点..."
                $foundUsbDevice = $true; Start-MobileHotspot; break
            }
        }
        if (-not $foundUsbDevice) { Write-Log "当前的网络连接都不是来自USB/RNDIS设备。" }
    }
} catch { Write-Log "在检查网络时发生严重错误: $($_.Exception.Message)" }
Write-Log "--- 脚本运行结束 ---`n"
'@

try {
    Write-Host "步骤 2: 正在创建核心脚本文件..."
    $scriptContent | Out-File -FilePath $scriptFullPath -Encoding utf8 -ErrorAction Stop
    Write-Host "  [成功] 核心脚本已创建。" -ForegroundColor Green
} catch {
    Write-Error "  [失败] 创建核心脚本文件时发生错误: $($_.Exception.Message)"
    Read-Host "请按 Enter 键退出。"
    exit
}

# 5. 使用XML定义并创建任务计划程序
try {
    Write-Host "步骤 3: 正在创建计划任务..."
    # 定义任务的XML配置
    $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and (EventID=10000)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId> <!-- S-1-5-18 is the SID for Local System -->
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <ExecutionTimeLimit>PT0S</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "$scriptFullPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    # 注册任务
    Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force -ErrorAction Stop
    Write-Host "  [成功] 已通过XML成功创建或更新计划任务: '$taskName'" -ForegroundColor Green
} catch {
    Write-Error "  [失败] 创建计划任务时发生错误: $($_.Exception.Message)"
    Read-Host "请按 Enter 键退出。"
    exit
}

Write-Host "---"
Write-Host "全部配置完成！" -ForegroundColor Green
Write-Host "现在，当您连接USB网络时，功能就会触发。"
Write-Host "日志文件位于: $installPath\log.txt"

Read-Host "请按 Enter 键退出窗口。"
