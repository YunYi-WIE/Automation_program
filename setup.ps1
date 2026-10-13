#Requires -Version 5.1

<#
.SYNOPSIS
    Java 开发环境一键配置脚本。
.DESCRIPTION
    自动安装 JDK 21、Maven、Git、VS Code、IntelliJ IDEA、Node.js、Docker Desktop、
    Notepad++、Windows Terminal 等开发工具，并配置 JAVA_HOME / MAVEN_HOME 环境变量。
.PARAMETER SkipManualReminders
    跳过「需要手动安装的软件」提示（小皮面板、Navicat）。
.PARAMETER DryRun
    演练模式：只打印将要执行的操作，不安装软件、不修改环境变量。用于安全预览。
.PARAMETER NonInteractive
    非交互模式：不等待任何按键输入，适合无人值守 / 远程执行。
.PARAMETER LogPath
    日志文件路径（可选）。指定后所有输出会同时写入该文件。
.EXAMPLE
    .\setup.ps1
.EXAMPLE
    .\setup.ps1 -DryRun
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup.ps1
.NOTES
    · 建议以管理员身份运行：写入「系统级」环境变量需要管理员权限。
      脚本会在检测到非管理员时询问是否自动提权重启。
    · 脚本是幂等的——已安装的软件会自动跳过，可安全重复执行多次。
    · 本文件必须以「UTF-8 with BOM」保存！
      Windows PowerShell 5.1 对无 BOM 的文件按系统 ANSI 代码页（简体中文为 GBK）
      解码，会导致中文乱码、字符串引号错位，进而报出大量语法错误。
      若用 VS Code 编辑：右下角编码选「UTF-8 with BOM」后保存。
#>

[CmdletBinding()]
param(
    [switch]$SkipManualReminders,
    [switch]$DryRun,
    [switch]$NonInteractive,
    [string]$LogPath = ""
)

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

# ──────────────────────────────────────────────
# 控制台编码：避免中文 / 框线字符在 PS 5.1 下乱码
# ──────────────────────────────────────────────

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding           = [System.Text.Encoding]::UTF8
} catch { }

# ──────────────────────────────────────────────
# 日志
# ──────────────────────────────────────────────

$script:LogFile = $null

if ($LogPath) {
    try {
        $logDir = Split-Path -Parent $LogPath
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $header = "===== 开发环境配置日志  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  ====="
        Set-Content -Path $LogPath -Value $header -Encoding UTF8
        $script:LogFile = $LogPath
    } catch {
        Write-Host "  [!] 日志文件创建失败: $($_.Exception.Message)" -ForegroundColor Magenta
    }
}

function Write-Log {
    param([string]$Text)
    if ($script:LogFile) {
        try { Add-Content -Path $script:LogFile -Value $Text -Encoding UTF8 } catch { }
    }
}

# ──────────────────────────────────────────────
# 颜色和输出函数
# ──────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Log ""
    Write-Log "===== $Message ====="
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [✓] $Message" -ForegroundColor Green
    Write-Log "  [OK]   $Message"
}

function Write-FAIL {
    param([string]$Message)
    Write-Host "  [✗] $Message" -ForegroundColor Red
    Write-Log "  [FAIL] $Message"
}

function Write-SKIP {
    param([string]$Message)
    Write-Host "  [—] $Message" -ForegroundColor Yellow
    Write-Log "  [SKIP] $Message"
}

function Write-INFO {
    param([string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor Blue
    Write-Log "  [INFO] $Message"
}

function Write-WARN {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Magenta
    Write-Log "  [WARN] $Message"
}

# ──────────────────────────────────────────────
# 交互封装（非交互模式下自动跳过）
# ──────────────────────────────────────────────

function Read-Input {
    param(
        [string]$Prompt,
        [string]$Default = ""
    )
    if ($NonInteractive) {
        Write-INFO "(非交互模式) $Prompt → 使用默认值 '$Default'"
        return $Default
    }
    $answer = Read-Host $Prompt
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer
}

function Pause-AnyKey {
    param([string]$Prompt = "按回车键退出...")
    if ($NonInteractive) { return }
    Read-Host $Prompt | Out-Null
}

# ──────────────────────────────────────────────
# 工具函数
# ──────────────────────────────────────────────

# 按 "a.b.c" 路径安全读取 JSON 对象的值（PS 5.1 不支持 ?. 与 ?? 运算符）
function Get-JsonValue {
    param(
        $Object,
        [string]$Path
    )
    if ($null -eq $Object) { return $null }
    $cur = $Object
    foreach ($seg in ($Path -split '\.')) {
        if ($null -eq $cur) { return $null }
        $prop = $cur.PSObject.Properties[$seg]
        if ($null -eq $prop) { return $null }
        $cur = $prop.Value
    }
    return $cur
}

# 判断 winget 包是否已安装（对 Id 做正则转义，避免 "." 被当作通配）
function Test-WingetPackage {
    param([string]$Id)
    try {
        $out = winget list --id $Id --exact --accept-source-agreements 2>&1 | Out-String
        if ($out -match 'No installed package') { return $false }
        return [bool]($out -match [regex]::Escape($Id))
    } catch {
        return $false
    }
}

# 写入系统级环境变量：DryRun 与权限不足时给出明确反馈，而不是静默失败
function Set-MachineEnv {
    param(
        [string]$Name,
        [string]$Value
    )
    if ($DryRun) {
        Write-INFO "[DryRun] 将设置系统环境变量 $Name = $Value"
        return $true
    }
    if (-not $script:IsAdmin) {
        Write-FAIL "非管理员权限，无法写入系统环境变量 $Name"
        Write-INFO "请以管理员身份重新运行本脚本，或手动设置该变量。"
        return $false
    }
    try {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Machine")
        return $true
    } catch {
        Write-FAIL "设置系统环境变量 $Name 失败: $($_.Exception.Message)"
        return $false
    }
}

# 是否支持虚拟化（Docker Desktop 前置条件之一）
function Test-Virtualization {
    try {
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($null -eq $cs) { return $null }
        return [bool]$cs.HypervisorPresent
    } catch {
        return $null
    }
}

# ──────────────────────────────────────────────
# 软件安装清单
# ──────────────────────────────────────────────

$packages = @(
    @{ Name = "JDK 21";             Id = "Oracle.JDK.21";                    Category = "Java 开发" },
    @{ Name = "Apache Maven";       Id = "Apache.Maven";                     Category = "Java 开发" },
    @{ Name = "Git";                Id = "Git.Git";                          Category = "版本控制" },
    @{ Name = "VS Code";            Id = "Microsoft.VisualStudioCode";       Category = "编辑器" },
    @{ Name = "IntelliJ IDEA (Community Edition)"; Id = "JetBrains.IntelliJIDEA.Community"; Category = "IDE" },
    @{ Name = "Node.js LTS";        Id = "OpenJS.NodeJS.LTS";                Category = "前端开发" },
    @{ Name = "Docker Desktop";     Id = "Docker.DockerDesktop";             Category = "容器" },
    @{ Name = "Notepad++";          Id = "Notepad++.Notepad++";              Category = "编辑器" },
    @{ Name = "Windows Terminal";   Id = "Microsoft.WindowsTerminal";        Category = "系统工具" }
)

$installResults = @()

# ──────────────────────────────────────────────
# 第一步：环境检查
# ──────────────────────────────────────────────

Clear-Host
Write-Host @"

╔══════════════════════════════════════════════╗
║     Java 开发环境一键配置脚本                  ║
║     适用于 Windows 10/11                      ║
╚══════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

if ($DryRun) {
    Write-WARN "演练模式（-DryRun）：不会安装任何软件，也不会修改环境变量。"
}

Write-Step "第一步：环境检查"

# 检查 winget
$wingetVersion = $null
try {
    $wingetVersion = (winget --version 2>$null | Out-String).Trim()
} catch { }

if (-not $wingetVersion) {
    Write-FAIL "未找到 winget。请确保系统已更新到最新版本，或从 Microsoft Store 安装「应用安装程序」。"
    Write-INFO "下载链接: https://aka.ms/getwinget"
    Pause-AnyKey "`n按回车键退出..."
    exit 1
}
Write-OK "winget 已就绪 (版本: $wingetVersion)"

# 当前 PowerShell 版本提示
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-INFO "当前为 Windows PowerShell $($PSVersionTable.PSVersion)（脚本已兼容 5.1+）"
}

# 检查管理员权限（非强制，但会影响系统环境变量写入）
$script:IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $script:IsAdmin) {
    Write-WARN "未以管理员身份运行。系统级环境变量（JAVA_HOME / MAVEN_HOME / Path）将无法写入。"
    Write-WARN "建议：右键此脚本 →「以管理员身份运行」可获得完整功能。"

    if (-not $NonInteractive -and -not $DryRun) {
        $relaunch = Read-Input "  是否以管理员身份重新启动脚本？(Y/N)" "N"
        if ($relaunch -match '^[Yy]') {
            Write-INFO "正在请求管理员权限..."
            try {
                $argList = @(
                    "-NoProfile",
                    "-ExecutionPolicy", "Bypass",
                    "-File", "`"$PSCommandPath`""
                )
                if ($SkipManualReminders) { $argList += "-SkipManualReminders" }
                Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
                exit 0
            } catch {
                Write-FAIL "提权失败（可能取消了 UAC 提示）: $($_.Exception.Message)"
                Write-INFO "将继续以普通权限执行，仅跳过系统级环境变量写入。"
            }
        }
    }
} else {
    Write-INFO "已获取管理员权限"
}

# ──────────────────────────────────────────────
# 第二步：批量安装软件
# ──────────────────────────────────────────────

Write-Step "第二步：通过 winget 安装软件"

$currentCategory = ""
foreach ($pkg in $packages) {
    # 类别标题
    if ($pkg.Category -ne $currentCategory) {
        $currentCategory = $pkg.Category
        Write-Host ""
        Write-Host "  --- $currentCategory ---" -ForegroundColor DarkGray
    }

    $name = $pkg.Name
    $id   = $pkg.Id

    Write-Host "  正在处理: $name ..." -NoNewline

    if ($id -eq "Docker.DockerDesktop") {
        $hv = Test-Virtualization
        if ($hv -eq $false) {
            Write-Host "`r" -NoNewline
            Write-WARN "$name — 未检测到 CPU 虚拟化，Docker 安装后可能无法启动"
            Write-INFO "请在 BIOS/UEFI 中开启 VT-x / AMD-V，并确认已启用 WSL2：wsl --install"
            Write-Host "  正在处理: $name ..." -NoNewline
        }
    }

    # 检查是否已安装
    if (Test-WingetPackage -Id $id) {
        Write-Host "`r" -NoNewline
        Write-SKIP "$name — 已安装，跳过"
        $installResults += @{ Name = $name; Status = "SKIP" }
        continue
    }

    # 演练模式：只打印命令
    if ($DryRun) {
        Write-Host "`r" -NoNewline
        Write-INFO "[DryRun] 将执行: winget install --id $id --exact --silent"
        $installResults += @{ Name = $name; Status = "DRYRUN" }
        continue
    }

    # 执行安装
    try {
        winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String | Out-Null

        # 再确认一次是否装上了（有些包 silent 模式不报错但也没装上）
        Start-Sleep -Seconds 2

        if (Test-WingetPackage -Id $id) {
            Write-Host "`r" -NoNewline
            Write-OK "$name — 安装成功"
            $installResults += @{ Name = $name; Status = "OK" }
        } else {
            # 源可能间歇性不可用，去掉 --silent 再试一次（部分包不支持静默安装）
            Write-Host "`r" -NoNewline
            Write-WARN "$name — 首次尝试未成功，正在重试..."

            winget install --id $id --exact --accept-source-agreements --accept-package-agreements 2>&1 | Out-String | Out-Null
            Start-Sleep -Seconds 3

            if (Test-WingetPackage -Id $id) {
                Write-Host "`r" -NoNewline
                Write-OK "$name — 重试后安装成功"
                $installResults += @{ Name = $name; Status = "OK" }
            } else {
                Write-Host "`r" -NoNewline
                Write-FAIL "$name — 安装失败，请稍后手动安装"
                Write-INFO "可手动执行: winget install --id $id --exact"
                $installResults += @{ Name = $name; Status = "FAIL" }
            }
        }
    } catch {
        Write-Host "`r" -NoNewline
        Write-FAIL "$name — 安装出错: $($_.Exception.Message)"
        $installResults += @{ Name = $name; Status = "FAIL" }
    }
}

# ──────────────────────────────────────────────
# 第三步：手动安装提示
# ──────────────────────────────────────────────

if (-not $SkipManualReminders) {
    Write-Step "第三步：需要手动安装的软件"

    Write-Host @"

  ┌─────────────────────────────────────────────────┐
  │  🟡 小皮面板 (phpStudy)                           │
  │     MySQL 管理工具                                │
  │     → 官网下载: https://www.xp.cn                │
  │     → 下载 Windows 版并安装                       │
  └─────────────────────────────────────────────────┘

  ┌─────────────────────────────────────────────────┐
  │  🟡 Navicat                                      │
  │     数据库管理客户端（付费软件）                    │
  │     → 官网: https://www.navicat.com.cn           │
  │     → 自行下载安装并激活许可证                     │
  └─────────────────────────────────────────────────┘

"@

    if (-not $NonInteractive) {
        Read-Host "  以上软件需要手动安装。看完后按回车继续环境配置" | Out-Null
    }
}

# ──────────────────────────────────────────────
# 第四步：配置环境变量
# ──────────────────────────────────────────────

Write-Step "第四步：配置环境变量"

# --- JAVA_HOME ---
Write-INFO "正在查找 JDK 21 安装路径..."

$javaHome = $null

# 方式1：注册表 JavaSoft\JDK 下所有 21.x（按版本号倒序，取最新）
try {
    $jdkBase = "HKLM:\SOFTWARE\JavaSoft\JDK"
    if (Test-Path $jdkBase) {
        $subkeys = Get-ChildItem -Path $jdkBase -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^21(\.|$)' } |
            Sort-Object { try { [version]$_.PSChildName } catch { [version]'0.0.0.0' } } -Descending

        foreach ($key in $subkeys) {
            $candidate = (Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue).JavaHome
            if ($candidate -and (Test-Path $candidate)) {
                $javaHome = $candidate
                break
            }
        }
    }
} catch { }

# 方式2：扫描常见安装目录
if (-not $javaHome) {
    $possiblePaths = @(
        "$env:ProgramFiles\Java\jdk-21*",
        "$env:ProgramFiles\Eclipse Adoptium\jdk-21*",
        "$env:ProgramFiles\Microsoft\jdk-21*",
        "${env:ProgramFiles(x86)}\Java\jdk-21*",
        "D:\Program Files\Java\jdk-21*"
    )
    foreach ($pattern in $possiblePaths) {
        $found = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $javaHome = $found.FullName
            break
        }
    }
}

if ($javaHome -and (Test-Path $javaHome)) {
    if (Set-MachineEnv -Name "JAVA_HOME" -Value $javaHome) {
        if (-not $DryRun) { Write-OK "JAVA_HOME = $javaHome" }
    }
} else {
    Write-FAIL "未找到 JDK 21 安装路径"
    Write-INFO "请手动设置: 搜索「编辑系统环境变量」→ 新建系统变量 JAVA_HOME = JDK 安装路径"
}

# --- MAVEN_HOME ---
Write-INFO "正在查找 Maven 安装路径..."

$mavenHome = $null

# 方式1：扫描常见目录，或目录内存在 bin\mvn.cmd
$mavenPatterns = @(
    "$env:ProgramFiles\Apache\Maven\*",
    "$env:ProgramFiles\apache-maven-*",
    "${env:ProgramFiles(x86)}\Apache\Maven\*",
    "C:\Program Files\Apache\apache-maven-*",
    "C:\apache-maven-*",
    "D:\Program Files\Apache\apache-maven-*",
    "D:\apache-maven-*"
)

foreach ($pattern in $mavenPatterns) {
    $candidates = @(Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue)
    foreach ($dir in $candidates) {
        if (Test-Path (Join-Path $dir.FullName "bin\mvn.cmd")) {
            $mavenHome = $dir.FullName
            break
        }
    }
    if ($mavenHome) { break }
}

if ($mavenHome) {
    if (Set-MachineEnv -Name "MAVEN_HOME" -Value $mavenHome) {
        if (-not $DryRun) { Write-OK "MAVEN_HOME = $mavenHome" }
    }
} else {
    Write-FAIL "未找到 Maven 安装路径"
    Write-INFO "请手动设置: 搜索「编辑系统环境变量」→ 新建系统变量 MAVEN_HOME = Maven 安装路径"
}

# --- 更新系统 Path ---
Write-INFO "正在更新系统 Path..."

$machinePath    = [Environment]::GetEnvironmentVariable("Path", "Machine")
$machinePathArr = @($machinePath -split ";" | Where-Object { $_ })

$pathsToAdd = @()
if ($javaHome  -and (Test-Path (Join-Path $javaHome  "bin"))) { $pathsToAdd += (Join-Path $javaHome  "bin") }
if ($mavenHome -and (Test-Path (Join-Path $mavenHome "bin"))) { $pathsToAdd += (Join-Path $mavenHome "bin") }

foreach ($p in $pathsToAdd) {
    if ($machinePathArr -notcontains $p) {
        $machinePath    = ($machinePath.TrimEnd(";") + ";" + $p)
        if (Set-MachineEnv -Name "Path" -Value $machinePath) {
            $machinePathArr += $p
            if (-not $DryRun) { Write-OK "已追加到 Path: $p" }
        }
    } else {
        Write-SKIP "Path 中已存在: $p"
    }
}

# --- 刷新当前会话的环境变量（合并 Machine + User + 当前，避免丢掉用户级 Path）---
if (-not $DryRun) {
    if ($javaHome)  { $env:JAVA_HOME  = $javaHome }
    if ($mavenHome) { $env:MAVEN_HOME = $mavenHome }

    $machineNow = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userNow    = [Environment]::GetEnvironmentVariable("Path", "User")
    $merged     = @($machineNow, $userNow, $env:Path) |
        Where-Object { $_ } |
        ForEach-Object { $_.TrimEnd(";") }

    $seen = @{}
    $finalParts = @()
    foreach ($chunk in $merged) {
        foreach ($seg in ($chunk -split ";")) {
            if (-not $seg) { continue }
            $key = $seg.TrimEnd("\").ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $finalParts += $seg
            }
        }
    }
    $env:Path = ($finalParts -join ";")
}

Write-INFO "环境变量已更新（新打开的终端窗口生效）"

# --- Git 配置 ---
Write-Step "Git 用户信息配置"

$configPath = Join-Path $PSScriptRoot "config.json"
$gitConfig  = $null

if (Test-Path $configPath) {
    try {
        $gitConfig = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-WARN "config.json 解析失败，将改为交互式询问: $($_.Exception.Message)"
    }
}

$gitName  = [string](Get-JsonValue -Object $gitConfig -Path "git.userName")
$gitEmail = [string](Get-JsonValue -Object $gitConfig -Path "git.userEmail")

if ([string]::IsNullOrWhiteSpace($gitName)) {
    $gitName = Read-Input "  请输入 Git 用户名 (如: Zhang San)"
}
if ([string]::IsNullOrWhiteSpace($gitEmail)) {
    $gitEmail = Read-Input "  请输入 Git 邮箱 (如: zhangsan@example.com)"
}

$gitCmd = Get-Command git -ErrorAction SilentlyContinue

if (-not $gitCmd) {
    Write-WARN "当前会话找不到 git 命令（可能刚安装、需重开终端）。"
    Write-INFO "稍后请手动执行以下命令完成配置："
    if ($gitName)  { Write-INFO "  git config --global user.name `"$gitName`"" }
    if ($gitEmail) { Write-INFO "  git config --global user.email `"$gitEmail`"" }
} elseif ($DryRun) {
    if ($gitName)  { Write-INFO "[DryRun] 将执行: git config --global user.name `"$gitName`"" }
    if ($gitEmail) { Write-INFO "[DryRun] 将执行: git config --global user.email `"$gitEmail`"" }
} else {
    if ($gitName) {
        git config --global user.name $gitName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "git config --global user.name '$gitName'"
        } else {
            Write-FAIL "设置 git user.name 失败（退出码 $LASTEXITCODE）"
        }
    }
    if ($gitEmail) {
        git config --global user.email $gitEmail 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "git config --global user.email '$gitEmail'"
        } else {
            Write-FAIL "设置 git user.email 失败（退出码 $LASTEXITCODE）"
        }
    }

    # 顺带修正 HTTPS 证书后端：部分环境 schannel 取凭据失败（SEC_E_NO_CREDENTIALS），
    # 改用 Git 自带的 OpenSSL 后端可正常 clone/push。
    $sslBackend = (git config --global --get http.sslBackend 2>$null | Out-String).Trim()
    if (-not $sslBackend) {
        Write-INFO "如需修复 GitHub 连接失败 (schannel: SEC_E_NO_CREDENTIALS)，可执行："
        Write-INFO "  git config --global http.sslBackend openssl"
    }
}

# ──────────────────────────────────────────────
# 第五步：验证安装
# ──────────────────────────────────────────────

Write-Step "第五步：验证安装"

$checks = @(
    @{ Name = "Java";     Cmd = "java";   Args = "-version" },
    @{ Name = "Javac";    Cmd = "javac";  Args = "-version" },
    @{ Name = "Maven";    Cmd = "mvn";    Args = "-version" },
    @{ Name = "Node.js";  Cmd = "node";   Args = "-v" },
    @{ Name = "npm";      Cmd = "npm";    Args = "-v" },
    @{ Name = "Git";      Cmd = "git";    Args = "--version" },
    @{ Name = "Docker";   Cmd = "docker"; Args = "--version" }
)

$verifyResults = @()

foreach ($check in $checks) {
    $cmdInfo = Get-Command $check.Cmd -ErrorAction SilentlyContinue

    if (-not $cmdInfo) {
        Write-FAIL "$($check.Name): 未找到（可能需要重启终端，或尚未安装）"
        $verifyResults += @{ Name = $check.Name; Status = "FAIL" }
        continue
    }

    try {
        $raw   = & $check.Cmd $check.Args 2>&1 | Out-String
        $lines = @(($raw -split "`r?`n") | Where-Object { $_.Trim() })
        # 优先取含版本号的行；并去掉 PowerShell 为原生命令 stderr 添加的 "xxx.exe : " 前缀
        $ver = $lines | Where-Object { $_ -match 'version|v?\d+\.\d+' } | Select-Object -First 1
        if (-not $ver) { $ver = $lines | Select-Object -First 1 }
        if ($ver) {
            $ver = ($ver -replace '^\s*[\w\.\-]+\.exe\s*:\s*', '').Trim()
            Write-OK "$($check.Name): $ver"
            $verifyResults += @{ Name = $check.Name; Status = "OK"; Version = $ver }
        } else {
            Write-OK "$($check.Name): 已安装"
            $verifyResults += @{ Name = $check.Name; Status = "OK" }
        }
    } catch {
        Write-FAIL "$($check.Name): 执行失败 — $($_.Exception.Message)"
        $verifyResults += @{ Name = $check.Name; Status = "FAIL" }
    }
}

# ──────────────────────────────────────────────
# 第六步：后续建议
# ──────────────────────────────────────────────

Write-Step "第六步：后续操作建议"

Write-Host @"

  📦 推荐安装的 VS Code 插件：

     Java 开发:
       Extension Pack for Java     (vscjava.vscode-java-pack)
       Spring Boot Extension Pack  (vmware.vscode-boot-dev-pack)
       Lombok Annotations Support  (vscjava.vscode-lombok)

     前端开发:
       ESLint                       (dbaeumer.vscode-eslint)
       Prettier - Code formatter    (esbenp.prettier-vscode)
       Vue / React 插件根据需要安装

     通用:
       Chinese (Simplified) Lang    (ms-ceintl.vscode-language-pack-zh-hans)

"@

Write-Host @"
  🐳 Docker 后续操作:
     Docker Desktop 安装后可能需要重启电脑，并确保已启用 WSL2:
       wsl --install
     首次启动后，打开终端拉取 Redis 镜像:
       docker pull redis
       docker run -d --name redis -p 6379:6379 redis

"@

# 工作目录
$workspacePath = [string](Get-JsonValue -Object $gitConfig -Path "paths.workspace")
if ([string]::IsNullOrWhiteSpace($workspacePath)) {
    $workspacePath = Join-Path $env:USERPROFILE "dev\workspace"
} else {
    # config.json 中可能写作 "~/dev/workspace"，需要展开 ~ 与环境变量
    $workspacePath = [Environment]::ExpandEnvironmentVariables($workspacePath)
    if ($workspacePath.StartsWith("~")) {
        $workspacePath = Join-Path $env:USERPROFILE ($workspacePath.Substring(1).TrimStart("\", "/"))
    }
}

if (Test-Path $workspacePath) {
    Write-SKIP "工作目录已存在: $workspacePath"
} elseif ($DryRun) {
    Write-INFO "[DryRun] 将创建工作目录: $workspacePath"
} else {
    try {
        New-Item -ItemType Directory -Path $workspacePath -Force -ErrorAction Stop | Out-Null
        Write-OK "已创建工作目录: $workspacePath"
    } catch {
        Write-WARN "创建工作目录失败: $($_.Exception.Message)"
    }
}

# ──────────────────────────────────────────────
# 汇总报告
# ──────────────────────────────────────────────

Write-Step "安装汇总报告"

Write-Host ""
Write-Host "  软件安装结果:" -ForegroundColor White
foreach ($r in $installResults) {
    switch ($r.Status) {
        "OK"     { Write-Host "    [✓] $($r.Name)" -ForegroundColor Green }
        "SKIP"   { Write-Host "    [—] $($r.Name)" -ForegroundColor Yellow }
        "DRYRUN" { Write-Host "    [>] $($r.Name)  (演练，未安装)" -ForegroundColor DarkGray }
        default  { Write-Host "    [✗] $($r.Name)" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "  环境验证结果:" -ForegroundColor White
foreach ($r in $verifyResults) {
    $verStr = ""
    if ($r.ContainsKey("Version") -and $r.Version) { $verStr = " — $($r.Version)" }
    if ($r.Status -eq "OK") {
        Write-Host "    [✓] $($r.Name)$verStr" -ForegroundColor Green
    } else {
        Write-Host "    [✗] $($r.Name)$verStr" -ForegroundColor Red
    }
}

$failCount   = @($installResults | Where-Object { $_.Status -eq "FAIL" }).Count
$okCount     = @($installResults | Where-Object { $_.Status -eq "OK" }).Count
$skipCount   = @($installResults | Where-Object { $_.Status -eq "SKIP" }).Count
$dryRunCount = @($installResults | Where-Object { $_.Status -eq "DRYRUN" }).Count

Write-Host ""
if ($DryRun) {
    Write-Host "  总计: 演练模式 — 将安装 $dryRunCount 个 | 已安装 $skipCount 个" -ForegroundColor White
} else {
    Write-Host "  总计: $okCount 个新安装 | $skipCount 个已跳过 | $failCount 个失败" -ForegroundColor White
}

if ($failCount -gt 0) {
    Write-Host ""
    Write-WARN "存在安装失败的软件，请检查上述 [✗] 项目并手动安装。"
    Write-INFO "常见原因: 网络问题、winget 源临时不可用。可重新运行此脚本重试。"
}

if (-not $script:IsAdmin -and -not $DryRun) {
    Write-Host ""
    Write-WARN "本次未以管理员身份运行，系统级环境变量可能未写入。"
    Write-INFO "若验证结果中出现 [✗]，请以管理员身份重新运行本脚本。"
}

Write-Host @"

  ✨ 配置完成！
  ⚠️  部分环境变量需要重启终端（或重启电脑）才能完全生效。
  ⚠️  Docker Desktop 首次使用需要启动 Docker 服务。

  小皮面板请手动下载安装: https://www.xp.cn
  Navicat 请自行获取安装: https://www.navicat.com.cn

"@ -ForegroundColor Cyan

if ($script:LogFile) {
    Write-INFO "本次日志已保存到: $($script:LogFile)"
}

Pause-AnyKey "按回车键退出..."
