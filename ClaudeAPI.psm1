# ClaudeAPI.psm1 - Claude API 服务管理模块

function Start-ClaudeAPI {
    param(
        [Parameter()]
        [int]$Port = 5000,
        
        [Parameter()]
        [string]$PythonPath = "D:\works\code\bedrock-access-gateway\.venv\Scripts\python.exe",
        
        [Parameter()]
        [string]$ScriptPath = "D:\works\code\awsClaudeApi\aws-claude.py",
        
        [Alias("h")]
        [switch]$Help,
        
        [switch]$Force, # 强制重启
        [switch]$Status, # 只查看状态
        [switch]$Stop, # 停止服务
        [switch]$ShowWindow,  # 显示窗口（默认隐藏）
        [switch]$DebugMode    # 是否为 debug 模式，默认 false
    )
    
    # 显示帮助信息
    if ($Help) {
        Write-Host @"

START-CLAUDEAPI - Claude API 服务管理工具
========================================

语法:
    Start-ClaudeAPI                     # 检查并启动服务（后台运行）
    Start-ClaudeAPI -ShowWindow         # 显示窗口启动服务
    Start-ClaudeAPI -Status             # 查看服务状态
    Start-ClaudeAPI -Stop               # 停止服务
    Start-ClaudeAPI -Force              # 强制重启服务
    Start-ClaudeAPI -Port 5000          # 指定端口
    Start-ClaudeAPI -DebugMode          # 启动为 debug 模式
    Start-ClaudeAPI -h                  # 显示帮助

参数:
    -Port          指定端口号（默认: 5000）
    -PythonPath    Python 可执行文件路径
    -ScriptPath    Python 脚本路径
    -ShowWindow    显示终端窗口（默认后台运行）
    -Force         强制重启服务（先停止再启动）
    -Status        只查看服务状态，不启动
    -Stop          停止服务
    -DebugMode     启动为 debug 模式（设置 DEBUG_MODE 环境变量为 true）
    -Help, -h      显示帮助信息

使用示例:
    Start-ClaudeAPI                     # 后台启动服务
    Start-ClaudeAPI -ShowWindow         # 显示窗口启动
    Start-ClaudeAPI -Status             # 查看状态
    Start-ClaudeAPI -Force              # 强制重启
    Start-ClaudeAPI -DebugMode          # 以 debug 模式启动

别名: claude, start-claude

"@ -ForegroundColor Cyan
        return
    }
    
    # 检查端口是否被占用的函数
    function Test-Port {
        param([int]$PortNumber)
        try {
            $connection = Test-NetConnection -ComputerName "localhost" -Port $PortNumber -WarningAction SilentlyContinue -InformationLevel Quiet
            return $connection
        }
        catch {
            # 备用方法
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $tcpClient.ConnectAsync("localhost", $PortNumber).Wait(1000)
                $result = $tcpClient.Connected
                $tcpClient.Close()
                return $result
            }
            catch {
                return $false
            }
        }
    }
    
    # 获取占用端口的进程
    function Get-PortProcess {
        param([int]$PortNumber)
        try {
            $processInfo = Get-NetTCPConnection -LocalPort $PortNumber -ErrorAction SilentlyContinue | 
            Select-Object -First 1 | 
            ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
            return $processInfo
        }
        catch {
            return $null
        }
    }
    
    # 检查文件是否存在
    if (-not (Test-Path $PythonPath)) {
        Write-Host "❌ Python 可执行文件不存在: $PythonPath" -ForegroundColor Red
        Write-Host "请检查路径或使用 -PythonPath 参数指定正确路径" -ForegroundColor Yellow
        return
    }
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "❌ Python 脚本不存在: $ScriptPath" -ForegroundColor Red
        Write-Host "请检查路径或使用 -ScriptPath 参数指定正确路径" -ForegroundColor Yellow
        return
    }
    
    $isPortInUse = Test-Port -PortNumber $Port
    $process = Get-PortProcess -PortNumber $Port
    
    # 显示状态信息
    if ($Status) {
        Write-Host ([string]::new('=', 50)) -ForegroundColor Gray
        Write-Host "Claude API 服务状态检查" -ForegroundColor Yellow
        Write-Host ([string]::new('=', 50)) -ForegroundColor Gray
        Write-Host "检查时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        Write-Host "端口 $Port : " -NoNewline
        if ($isPortInUse) {
            Write-Host "占用中 ✓" -ForegroundColor Green
            if ($process) {
                Write-Host "进程信息:" -ForegroundColor Cyan
                Write-Host "  - 进程名: $($process.ProcessName)" -ForegroundColor White
                Write-Host "  - 进程 ID: $($process.Id)" -ForegroundColor White
                Write-Host "  - 启动时间: $($process.StartTime)" -ForegroundColor White
                Write-Host "  - CPU 使用: $([math]::Round($process.CPU, 2))s" -ForegroundColor White
                Write-Host "  - 内存使用: $([math]::Round($process.WorkingSet64/1MB, 2))MB" -ForegroundColor White
            }
            Write-Host "服务地址:" -ForegroundColor Blue
            Write-Host "  - http://localhost:$Port" -ForegroundColor White
            Write-Host "  - http://127.0.0.1:$Port" -ForegroundColor White
            
            # 测试服务响应
            # try {
            #     $testResult = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 3 -ErrorAction SilentlyContinue
            #     Write-Host "服务响应: 正常 ✓ (HTTP $($testResult.StatusCode))" -ForegroundColor Green
            # } catch {
            #     Write-Host "服务响应: 异常 ❌" -ForegroundColor Red
            #     Write-Host "  错误: $($_.Exception.Message)" -ForegroundColor Yellow
            # }
        }
        else {
            Write-Host "未占用 ❌" -ForegroundColor Red
            Write-Host "服务状态: 未运行" -ForegroundColor Yellow
        }
        Write-Host ([string]::new('=', 50)) -ForegroundColor Gray
        return
    }
    
    # 停止服务
    if ($Stop) {
        if ($isPortInUse -and $process) {
            Write-Host "正在停止 Claude API 服务..." -ForegroundColor Yellow
            Write-Host "进程信息: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
            try {
                Stop-Process -Id $process.Id -Force
                Write-Host "等待进程结束..." -NoNewline -ForegroundColor Yellow
                for ($i = 0; $i -lt 5; $i++) {
                    Start-Sleep -Seconds 1
                    Write-Host "." -NoNewline -ForegroundColor Yellow
                    if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
                        break
                    }
                }
                Write-Host ""
                Write-Host "✓ 服务已停止" -ForegroundColor Green
            }
            catch {
                Write-Host ""
                Write-Host "❌ 停止服务失败: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        else {
            Write-Host "服务未运行，无需停止" -ForegroundColor Yellow
        }
        return
    }
    
    # 强制重启
    if ($Force -and $isPortInUse) {
        Write-Host "强制重启服务..." -ForegroundColor Yellow
        if ($process) {
            try {
                Write-Host "停止现有服务 (PID: $($process.Id))..." -ForegroundColor Gray
                Stop-Process -Id $process.Id -Force
                Write-Host "等待服务完全停止..." -NoNewline -ForegroundColor Yellow
                for ($i = 0; $i -lt 5; $i++) {
                    Start-Sleep -Seconds 1
                    Write-Host "." -NoNewline -ForegroundColor Yellow
                    if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
                        break
                    }
                }
                Write-Host ""
                Write-Host "✓ 已停止现有服务" -ForegroundColor Green
            }
            catch {
                Write-Host ""
                Write-Host "⚠️ 停止现有服务时遇到问题: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        $isPortInUse = $false  # 重置状态以启动新服务
    }
    
    # 检查服务状态并启动
    if ($isPortInUse) {
        Write-Host "✓ Claude API 服务已在端口 $Port 上运行" -ForegroundColor Green
        if ($process) {
            Write-Host "进程信息: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Cyan
            Write-Host "启动时间: $($process.StartTime)" -ForegroundColor Gray
        }
        Write-Host "服务地址: http://localhost:$Port" -ForegroundColor Blue
        
        # 测试服务是否响应
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Host "服务状态: 正常响应 ✓" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠️ 服务可能未完全启动或存在问题" -ForegroundColor Yellow
            Write-Host "   使用 'claude -Status' 查看详细状态" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "启动 Claude API 服务..." -ForegroundColor Yellow
        Write-Host "配置信息:" -ForegroundColor Gray
        Write-Host "  Python: $PythonPath" -ForegroundColor Gray
        Write-Host "  脚本: $ScriptPath" -ForegroundColor Gray
        Write-Host "  端口: $Port" -ForegroundColor Gray
        Write-Host "  模式: $(if ($ShowWindow) { '显示窗口' } else { '后台运行（隐藏窗口）' })" -ForegroundColor Gray
        Write-Host "  Debug: $(if ($DebugMode) { '开启' } else { '关闭' })" -ForegroundColor Gray
        Write-Host "----------------------------------------" -ForegroundColor Gray
        
        try {
            # 启动前设置 DEBUG_MODE 环境变量
            if ($DebugMode) {
                $env:DEBUG_MODE = "true"
            } else {
                $env:DEBUG_MODE = "false"
            }
            if ($ShowWindow) {
                # 显示窗口模式
                Write-Host "使用显示窗口模式启动..." -ForegroundColor Blue
                $processArgs = @{
                    FilePath     = $PythonPath
                    ArgumentList = @($ScriptPath)
                    WindowStyle  = 'Normal'
                    PassThru     = $true
                }
                $newProcess = Start-Process @processArgs
            }
            else {
                # 隐藏窗口模式 - 修复版本
                Write-Host "使用后台模式启动..." -ForegroundColor Blue
                
                # 方法1：直接使用 Python（推荐）
                try {
                    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
                    $processInfo.FileName = $PythonPath
                    $processInfo.Arguments = "`"$ScriptPath`""
                    $processInfo.WorkingDirectory = Split-Path $ScriptPath -Parent
                    $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                    $processInfo.UseShellExecute = $false
                    
                    $newProcess = New-Object System.Diagnostics.Process
                    $newProcess.StartInfo = $processInfo
                    $null = $newProcess.Start()
                }
                catch {
                    # 方法2：使用 cmd 作为中介
                    Write-Host "使用备用启动方法..." -ForegroundColor Blue
                    $cmdArgs = "/c `"cd /d `"$(Split-Path $ScriptPath -Parent)`" && `"$PythonPath`" `"$ScriptPath`"`""
                    $processArgs = @{
                        FilePath     = 'cmd.exe'
                        ArgumentList = @($cmdArgs)
                        WindowStyle  = 'Hidden'
                        PassThru     = $true
                    }
                    $newProcess = Start-Process @processArgs
                }
            }
            
            if ($newProcess) {
                Write-Host "✓ 服务启动中..." -ForegroundColor Green
                Write-Host "进程 ID: $($newProcess.Id)" -ForegroundColor Cyan
                if (-not $ShowWindow) {
                    Write-Host "运行模式: 后台运行（无窗口）" -ForegroundColor Blue
                }
                else {
                    Write-Host "运行模式: 显示窗口" -ForegroundColor Blue
                }
                
                # 等待服务启动
                Write-Host "等待服务启动完成" -NoNewline -ForegroundColor Yellow
                $maxWaitTime = 20
                for ($i = 0; $i -lt $maxWaitTime; $i++) {
                    Start-Sleep -Seconds 1
                    Write-Host "." -NoNewline -ForegroundColor Yellow
                    
                    if (Test-Port -PortNumber $Port) {
                        Write-Host ""
                        Write-Host "✓ 服务启动成功!" -ForegroundColor Green
                        Write-Host ""
                        Write-Host "服务信息:" -ForegroundColor Cyan
                        Write-Host "  地址: http://localhost:$Port" -ForegroundColor White
                        Write-Host "  地址: http://127.0.0.1:$Port" -ForegroundColor White
                        Write-Host "  进程: $($newProcess.Id)" -ForegroundColor White
                        
                        Write-Host ""
                        Write-Host "管理命令:" -ForegroundColor Cyan
                        Write-Host "  查看状态: claude -Status" -ForegroundColor Gray
                        Write-Host "  停止服务: claude -Stop" -ForegroundColor Gray
                        Write-Host "  重启服务: claude -Force" -ForegroundColor Gray
                        if (-not $ShowWindow) {
                            Write-Host "  显示窗口: claude -ShowWindow" -ForegroundColor Gray
                        }
                        return
                    }
                }
                Write-Host ""
                Write-Host "⚠️ 服务启动时间超过预期 ($maxWaitTime 秒)" -ForegroundColor Yellow

                Write-Host "服务可能仍在启动中，请稍后使用以下命令检查:" -ForegroundColor Gray
                Write-Host "  claude -Status" -ForegroundColor White
                
            }
            else {
                Write-Host "❌ 无法获取启动的进程信息" -ForegroundColor Red
            }
            
        }
        catch {
            Write-Host ""
            Write-Host "❌ 启动服务失败: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "请检查以下内容:" -ForegroundColor Yellow
            Write-Host "  1. Python 路径是否正确: $PythonPath" -ForegroundColor Gray
            Write-Host "  2. Python 脚本是否存在: $ScriptPath" -ForegroundColor Gray
            Write-Host "  3. 端口 $Port 是否被其他程序占用" -ForegroundColor Gray
            Write-Host "  4. 权限是否足够" -ForegroundColor Gray
        }
    }
}

# 自动启动函数
function Initialize-ClaudeAPI {
    param(
        [switch]$Silent,
        [switch]$ShowWindow
    )
    
    if (-not $Silent) {
        Write-Host "正在检查 Claude API 服务..." -ForegroundColor Yellow
    }
    
    try {
        $isRunning = Test-NetConnection -ComputerName "localhost" -Port 5000 -WarningAction SilentlyContinue -InformationLevel Quiet
        
        if (-not $isRunning) {
            if (-not $Silent) {
                Write-Host "Claude API 服务未运行，正在启动..." -ForegroundColor Yellow
            }
            if ($ShowWindow) {
                Start-ClaudeAPI -ShowWindow
            }
            else {
                Start-ClaudeAPI
            }
        }
        else {
            if (-not $Silent) {
                Write-Host "✓ Claude API 服务已运行在端口 5000" -ForegroundColor Green
            }
        }
    }
    catch {
        if (-not $Silent) {
            Write-Host "检查服务状态时出错: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 快速重启函数
function Restart-ClaudeAPI {
    param(
        [switch]$ShowWindow
    )
    Write-Host "重启 Claude API 服务..." -ForegroundColor Yellow
    if ($ShowWindow) {
        Start-ClaudeAPI -Force -ShowWindow
    }
    else {
        Start-ClaudeAPI -Force
    }
}

# 获取服务日志函数（如果需要的话）
function Get-ClaudeAPILog {
    param(
        [int]$Lines = 50
    )
    
    Write-Host "查看 Claude API 服务相关进程..." -ForegroundColor Yellow
    
    # 查找相关的 Python 进程
    $pythonProcesses = Get-Process -Name "python*" -ErrorAction SilentlyContinue | 
    Where-Object { $_.CommandLine -like "*aws-claude*" -or $_.CommandLine -like "*claude*" }
    
    if ($pythonProcesses) {
        Write-Host "找到相关进程:" -ForegroundColor Green
        $pythonProcesses | ForEach-Object {
            Write-Host "  PID: $($_.Id), 名称: $($_.ProcessName), 启动时间: $($_.StartTime)" -ForegroundColor White
        }
    }
    else {
        # 查找占用 5000 端口的进程
        try {
            $portProcess = Get-NetTCPConnection -LocalPort 5000 -ErrorAction SilentlyContinue | 
            ForEach-Object { Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue }
            if ($portProcess) {
                Write-Host "端口 5000 被以下进程占用:" -ForegroundColor Yellow
                Write-Host "  PID: $($portProcess.Id), 名称: $($portProcess.ProcessName), 启动时间: $($portProcess.StartTime)" -ForegroundColor White
            }
            else {
                Write-Host "未找到相关进程，服务可能未运行" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "无法查询进程信息: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 导出函数
Export-ModuleMember -Function Start-ClaudeAPI, Initialize-ClaudeAPI, Restart-ClaudeAPI, Get-ClaudeAPILog

# 创建别名
New-Alias -Name claude -Value Start-ClaudeAPI -Force
New-Alias -Name claude-restart -Value Restart-ClaudeAPI -Force
New-Alias -Name claude-log -Value Get-ClaudeAPILog -Force

# 导出别名
Export-ModuleMember -Alias claude, claude-restart, claude-log

# 模块加载时的初始化消息
Write-Host ""
Write-Host "✓ Claude API 管理模块已加载" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host "可用命令:" -ForegroundColor Cyan
Write-Host "  claude              - 启动服务（后台运行）" -ForegroundColor White
Write-Host "  claude -ShowWindow  - 启动服务（显示窗口）" -ForegroundColor White
Write-Host "  claude -Status      - 查看服务状态" -ForegroundColor White
Write-Host "  claude -Stop        - 停止服务" -ForegroundColor White
Write-Host "  claude -Force       - 强制重启服务" -ForegroundColor White
Write-Host "  claude -h           - 显示详细帮助" -ForegroundColor White
Write-Host "  claude-restart      - 快速重启服务" -ForegroundColor White
Write-Host "  claude-log          - 查看进程信息" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""
