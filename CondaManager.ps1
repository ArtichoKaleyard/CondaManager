#Requires -Version 5.1
<#
.SYNOPSIS
    智能 Conda 环境管理器
.DESCRIPTION
    自动检测项目环境(uv/venv)并处理 Conda 冲突
.NOTES
    编码: UTF-8 with BOM (重要！必须用 BOM 保存)
#>

param([switch]$StartupMode)

# ============ 配置区 ============
$SCRIPT_PATH = $MyInvocation.MyCommand.Path
$MARKER_START = "# >>> CondaManager Start >>>"
$MARKER_END = "# <<< CondaManager End <<<"
$PROFILE_PATH = $PROFILE

# ============ 核心逻辑：环境冲突检测 ============
function Invoke-CondaConflictCheck {
    # 如果 Conda 未激活，直接返回
    if (-not $env:CONDA_PREFIX) { 
        return 
    }
    
    # 检测项目环境标记文件
    $projectMarkers = @("uv.lock", ".venv", "pyproject.toml", "requirements.txt")
    $hasProject = $projectMarkers | Where-Object { Test-Path $_ }
    
    if ($hasProject) {
        Write-Host ""
        Write-Host "[!] 检测到项目环境" -ForegroundColor Yellow
        Write-Host "    当前 Conda 环境: $env:CONDA_DEFAULT_ENV" -ForegroundColor Cyan
        
        $choice = Read-Host "是否关闭 Conda 避免依赖冲突? [Y/n] (默认 Y)"
        
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -match '^[Yy]') {
            conda deactivate 2>$null
            Write-Host "✓ Conda 环境已关闭" -ForegroundColor Green
        } else {
            Write-Host "已保留 Conda 环境" -ForegroundColor Cyan
        }
    } else {
        # 非项目目录，自动关闭 base 环境（保持终端清爽）
        if ($env:CONDA_DEFAULT_ENV -eq 'base') {
            conda deactivate 2>$null
            Write-Host "[CondaManager] 已自动关闭 base 环境" -ForegroundColor DarkGray
        }
    }
}

# ============ 主流程 ============
if ($StartupMode) {
    # --- 模式 A: Profile 自动启动模式 ---
    Invoke-CondaConflictCheck
    
} else {
    # --- 模式 B: 交互式部署/卸载模式 ---
    Clear-Host
    Write-Host "=============================" -ForegroundColor Magenta
    Write-Host "   Conda 管理器 - 部署工具  " -ForegroundColor Magenta
    Write-Host "=============================" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "脚本位置: " -NoNewline -ForegroundColor Gray
    Write-Host $SCRIPT_PATH -ForegroundColor White
    Write-Host ""
    
    # 检测部署状态
    $isDeployed = $false
    if (Test-Path $PROFILE_PATH) {
        $profileContent = Get-Content $PROFILE_PATH -Raw -ErrorAction SilentlyContinue
        $isDeployed = $profileContent -match [regex]::Escape($MARKER_START)
    }
    
    if (-not $isDeployed) {
        # -------- 部署流程 --------
        Write-Host "当前状态: " -NoNewline -ForegroundColor Gray
        Write-Host "[未部署]" -ForegroundColor Red
        Write-Host ""
        Write-Host "部署后每次打开终端都会帮你看着项目环境~" -ForegroundColor DarkGray
        Write-Host "再也不用担心 Conda 和 uv/venv 打架啦 ヽ(°▽°)ノ" -ForegroundColor DarkGray
        Write-Host ""
        
        $confirm = Read-Host "要不要部署到 PowerShell Profile? [Y/n] (默认 Y)"
        
        if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm -match '^[Yy]') {
            # 确保 Profile 目录存在
            $profileDir = Split-Path $PROFILE_PATH -Parent
            if (-not (Test-Path $profileDir)) {
                New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
            }
            
            # 确保 Profile 文件存在
            if (-not (Test-Path $PROFILE_PATH)) {
                New-Item -ItemType File -Path $PROFILE_PATH -Force | Out-Null
            }
            
            # 构建注入代码
            $injectionCode = @"

$MARKER_START
. "$SCRIPT_PATH" -StartupMode
$MARKER_END
"@
            
            # 写入 Profile
            Add-Content -Path $PROFILE_PATH -Value $injectionCode -Encoding UTF8
            
            Write-Host ""
            Write-Host "✓ 部署成功！下次启动终端即可生效" -ForegroundColor Green
            Write-Host ""
            Write-Host "Tips: cd 到项目目录试试，会自动提示的哦 (๑•̀ㅂ•́)و✧" -ForegroundColor DarkGray
        } else {
            Write-Host ""
            Write-Host "好吧，那就不部署了 ( ´･ω･`)" -ForegroundColor Yellow
        }
        
    } else {
        # -------- 卸载流程 --------
        Write-Host "当前状态: " -NoNewline -ForegroundColor Gray
        Write-Host "[已部署]" -ForegroundColor Green
        Write-Host ""
        Write-Host "用得还顺手吗？要卸载吗？" -ForegroundColor DarkGray
        Write-Host ""
        
        $choice = Read-Host "确认卸载? [y/N] (默认 N，也就是不卸载)"
        
        if ($choice -match '^[Yy]') {
            $profileContent = Get-Content $PROFILE_PATH -Raw
            
            # 使用正则移除标记块（支持跨行）
            $pattern = "(?ms)`r?`n?$([regex]::Escape($MARKER_START)).*?$([regex]::Escape($MARKER_END))"
            $newContent = $profileContent -replace $pattern, ''
            
            # 清理多余空行
            $newContent = $newContent.TrimEnd()
            
            # 写回文件
            $newContent | Out-File $PROFILE_PATH -Encoding UTF8 -NoNewline
            
            Write-Host ""
            Write-Host "✓ 卸载成功！世界线已恢复" -ForegroundColor Green
        } else {
            Write-Host ""
            Write-Host "懂了，手滑了是吧 (￣▽￣)ノ 那就继续用着~" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "按任意键退出..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}