# ===================================================================
# 卸载脚本 v5 (配套 Install-v5.ps1)
# ===================================================================

# 1. 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "此脚本需要管理员权限。请以管理员身份运行。"
    Read-Host "按 Enter 键退出。"
    exit
}

Clear-Host
$taskName = "Auto USB Hotspot Trigger"
$installPath = "C:\Users\Public\Documents\AutoHotspot"

Write-Host "--- 开始卸载自动热点功能 (v5) ---" -ForegroundColor Yellow

# 2. 停止并注销计划任务
Write-Host "步骤 1: 正在移除计划任务..."
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  [成功] 已移除计划任务: '$taskName'" -ForegroundColor Green
} else {
    Write-Host "  [信息] 计划任务 '$taskName' 不存在，无需移除。" -ForegroundColor Cyan
}

# 3. 删除脚本文件和目录
Write-Host "步骤 2: 正在删除文件目录..."
if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
    Write-Host "  [成功] 已删除目录及其内容: $installPath" -ForegroundColor Green
} else {
    Write-Host "  [信息] 目录 '$installPath' 不存在，无需删除。" -ForegroundColor Cyan
}

Write-Host "---"
Write-Host "卸载完成！所有相关组件均已清理。" -ForegroundColor Green
Read-Host "请按 Enter 键退出窗口。"