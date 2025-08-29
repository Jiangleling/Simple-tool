1. Obtain PowerShell script execution permission through administrator permissions
    通过管理员权限获取powershell执行脚本权限

2、Execute! (If the execution fails, check whether the current system security policy prohibits the user from executing the script.)
    执行！（如执行失败，请检查当前系统安全策略是否禁止用户执行脚本） 



    You can temporarily change the system security policy under this powershell window by using the command: Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

    可通过 命令： Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass  临时改变此powershell窗口下系统安全策略
