#Requires -Version 5.1

<#
.SYNOPSIS
    Java 开发环境一键配置脚本
.DESCRIPTION
    自动安装 JDK 21、Maven、Git、VS Code、IntelliJ IDEA、Node.js、Docker Desktop、
    Notepad++、Windows Terminal 等开发工具，并配置环境变量。
.NOTES
    以管理员身份运行可获得最佳效果。
    脚本是幂等的——已安装的软件会自动跳过，可安全重复执行。
#>

param(
    [switch]$SkipManualReminders  # 跳过手动安装提示
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# ──────────────────────────────────────────────
# 颜色和输出函数
# ──────────────────────────────────────────────

function Write-Step {
    param([string]$Message)
    Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "  [✓] $Message" -ForegroundColor Green
}

function Write-FAIL {
    param([string]$Message)
    Write-Host "  [✗] $Message" -ForegroundColor Red
}

function Write-SKIP {
    param([string]$Message)
    Write-Host "  [—] $Message" -ForegroundColor Yellow
}

function Write-INFO {
    param([string]$Message)
    Write-Host "  [i] $Message" -ForegroundColor Blue
}

function Write-WARN {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor Magenta
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

Write-Step "第一步：环境检查"

# 检查 winget
$wingetVersion = $null
try {
    $wingetVersion = winget --version 2>$null
} catch {}

if (-not $wingetVersion) {
    Write-FAIL "未找到 winget。请确保 Windows 11 系统已更新到最新版本，或从 Microsoft Store 安装「应用安装程序」。"
    Write-INFO "下载链接: https://aka.ms/getwinget"
    Read-Host "`n按任意键退出..."
    exit 1
}
Write-OK "winget 已就绪 (版本: $wingetVersion)"

# 检查管理员权限（警告但不强制）
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-WARN "未以管理员身份运行。部分软件安装可能弹出 UAC 提示框，请手动点击「是」。"
    Write-WARN "建议：右键此脚本 →「以管理员身份运行」可获得更流畅的体验。"
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
        Write-Host "`n  --- $currentCategory ---" -ForegroundColor DarkGray
    }

    $name = $pkg.Name
    $id   = $pkg.Id

    Write-Host "  正在处理: $name ..." -NoNewline

    # 检查是否已安装
    $alreadyInstalled = $false
    try {
        $existing = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
        if ($existing -match $id) {
            $alreadyInstalled = $true
        }
    } catch {}

    if ($alreadyInstalled) {
        Write-Host "`r" -NoNewline
        Write-SKIP "$name — 已安装，跳过"
        $installResults += @{ Name = $name; Status = "SKIP" }
        continue
    }

    # 执行安装
    try {
        $installOutput = winget install --id $id --exact --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-String

        # 再确认一次是否装上了（有些包 silent 模式不报错但也没装上）
        Start-Sleep -Seconds 2
        $verify = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String

        if ($verify -match $id) {
            Write-Host "`r" -NoNewline
            Write-OK "$name — 安装成功"
            $installResults += @{ Name = $name; Status = "OK" }
        } else {
            # GitHub 等源可能间歇性不可用，给一次重试
            Write-Host "`r" -NoNewline
            Write-WARN "$name — 首次尝试未成功，正在重试..."

            winget install --id $id --exact --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            $verify2 = winget list --id $id --exact --accept-source-agreements 2>$null | Out-String

            if ($verify2 -match $id) {
                Write-OK "$name — 重试后安装成功"
                $installResults += @{ Name = $name; Status = "OK" }
            } else {
                Write-FAIL "$name — 安装失败，请稍后手动安装"
                $installResults += @{ Name = $name; Status = "FAIL" }
            }
        }
    } catch {
        Write-Host "`r" -NoNewline
        Write-FAIL "$name — 安装出错: $_"
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

    Read-Host "  以上软件需要手动安装。看完后按回车继续环境配置"
}

# ──────────────────────────────────────────────
# 第四步：配置环境变量
# ──────────────────────────────────────────────

Write-Step "第四步：配置环境变量"

# --- JAVA_HOME ---
Write-INFO "正在查找 JDK 21 安装路径..."

$javaHome = $null

# 方式1：注册表查询（最可靠）
try {
    $regPaths = @(
        "HKLM:\SOFTWARE\JavaSoft\JDK\21",
        "HKLM:\SOFTWARE\JavaSoft\JDK\21.0.12",
        "HKLM:\SOFTWARE\JavaSoft\JDK\21.0.7"
    )
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            $javaHome = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).JavaHome
            if ($javaHome) { break }
        }
    }
} catch {}

# 方式2：遍历 JavaSoft 查找所有 21.x 版本
if (-not $javaHome) {
    try {
        $jdkBase = "HKLM:\SOFTWARE\JavaSoft\JDK"
        if (Test-Path $jdkBase) {
            $subkeys = Get-ChildItem -Path $jdkBase -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match "^21" } |
                Sort-Object { [version]$_.PSChildName } -Descending
            foreach ($key in $subkeys) {
                $javaHome = (Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue).JavaHome
                if ($javaHome) { break }
            }
        }
    } catch {}
}

# 方式3：扫描常见目录
if (-not $javaHome) {
    $possiblePaths = @(
        "$env:ProgramFiles\Java\jdk-21*",
        "${env:ProgramFiles(x86)}\Java\jdk-21*",
        "D:\Program Files\Java\jdk-21*"
    )
    foreach ($pattern in $possiblePaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $javaHome = $found.FullName
            break
        }
    }
}

if ($javaHome -and (Test-Path $javaHome)) {
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "Machine")
    Write-OK "JAVA_HOME = $javaHome"
} else {
    Write-FAIL "未找到 JDK 21 安装路径"
    Write-INFO "请手动设置: 搜索「编辑系统环境变量」→ 新建系统变量 JAVA_HOME = JDK 安装路径"
}

# --- MAVEN_HOME ---
Write-INFO "正在查找 Maven 安装路径..."

$mavenHome = $null

# 方式1：扫描程序目录
$mavenDirs = @(
    "$env:ProgramFiles\Apache\Maven\*",
    "$env:ProgramFiles\apache-maven-*",
    "${env:ProgramFiles(x86)}\Apache\Maven\*",
    "C:\Program Files\Apache\apache-maven-*",
    "D:\Program Files\Apache\apache-maven-*"
)

foreach ($pattern in $mavenDirs) {
    $found = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $mavenHome = $found.FullName
        break
    }
}

# 方式2：检查目标目录里面有没有 bin\mvn.cmd
if (-not $mavenHome) {
    $extraDirs = @(
        "C:\Program Files\Apache\Maven",
        "C:\apache-maven*",
        "D:\apache-maven*"
    )
    foreach ($dir in (Get-ChildItem -Path $extraDirs -Directory -ErrorAction SilentlyContinue)) {
        if (Test-Path "$dir\bin\mvn.cmd") {
            $mavenHome = $dir.FullName
            break
        }
    }
}

if ($mavenHome -and (Test-Path $mavenHome)) {
    [Environment]::SetEnvironmentVariable("MAVEN_HOME", $mavenHome, "Machine")
    Write-OK "MAVEN_HOME = $mavenHome"
} else {
    Write-FAIL "未找到 Maven 安装路径"
    Write-INFO "请手动设置: 搜索「编辑系统环境变量」→ 新建系统变量 MAVEN_HOME = Maven 安装路径"

    # 尝试列出可能的 Maven 目录
    Write-INFO "正在搜索可能的 Maven 目录..."
    $foundMaven = Get-ChildItem -Path "C:\" -Directory -Filter "*maven*" -Depth 2 -ErrorAction SilentlyContinue
    if ($foundMaven) {
        foreach ($f in $foundMaven) {
            if (Test-Path "$($f.FullName)\bin\mvn.cmd") {
                Write-INFO "发现: $($f.FullName)"
            }
        }
    }
}

# --- 更新 Path ---
Write-INFO "正在更新系统 Path..."

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";"
$pathsToAdd = @()

if ($javaHome -and (Test-Path "$javaHome\bin")) {
    $pathsToAdd += "$javaHome\bin"
}
if ($mavenHome -and (Test-Path "$mavenHome\bin")) {
    $pathsToAdd += "$mavenHome\bin"
}

foreach ($p in $pathsToAdd) {
    if ($machinePath -notcontains $p) {
        $newPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";$p"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-OK "已追加到 Path: $p"
    } else {
        Write-SKIP "Path 中已存在: $p"
    }
}

# 刷新当前会话的 Path
$env:JAVA_HOME = $javaHome
$env:MAVEN_HOME = $mavenHome
foreach ($p in $pathsToAdd) {
    if ($env:Path -notcontains $p) {
        $env:Path = "$env:Path;$p"
    }
}

Write-INFO "环境变量已更新（新打开的终端窗口生效）"

# --- Git 配置 ---
Write-Step "Git 用户信息配置"

$configPath = Join-Path $PSScriptRoot "config.json"
$gitConfig = $null
if (Test-Path $configPath) {
    try {
        $gitConfig = Get-Content $configPath -Raw | ConvertFrom-Json
    } catch {}
}

$gitName = $gitConfig?.git?.userName ?? ""
$gitEmail = $gitConfig?.git?.userEmail ?? ""

if ([string]::IsNullOrWhiteSpace($gitName)) {
    $gitName = Read-Host "  请输入 Git 用户名 (如: Zhang San)"
}
if ([string]::IsNullOrWhiteSpace($gitEmail)) {
    $gitEmail = Read-Host "  请输入 Git 邮箱 (如: zhangsan@example.com)"
}

if ($gitName) {
    git config --global user.name $gitName 2>$null
    Write-OK "git config --global user.name '$gitName'"
}
if ($gitEmail) {
    git config --global user.email $gitEmail 2>$null
    Write-OK "git config --global user.email '$gitEmail'"
}

# ──────────────────────────────────────────────
# 第五步：验证安装
# ──────────────────────────────────────────────

Write-Step "第五步：验证安装"

# 刷新 PATH（当前会话生效）
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")

$checks = @(
    @{ Name = "Java";     Cmd = "java";        Args = "-version" },
    @{ Name = "Javac";    Cmd = "javac";       Args = "-version" },
    @{ Name = "Maven";    Cmd = "mvn";         Args = "-version" },
    @{ Name = "Node.js";  Cmd = "node";        Args = "-v" },
    @{ Name = "npm";      Cmd = "npm";         Args = "-v" },
    @{ Name = "Git";      Cmd = "git";         Args = "--version" },
    @{ Name = "Docker";   Cmd = "docker";      Args = "--version" }
)

$verifyResults = @()
foreach ($check in $checks) {
    try {
        $output = & $check.Cmd $check.Args 2>&1 | Select-Object -First 1
        if ($LASTEXITCODE -eq 0 -or $output) {
            $ver = ($output -join " ").Trim()
            Write-OK "$($check.Name): $ver"
            $verifyResults += @{ Name = $check.Name; Status = "OK"; Version = $ver }
        } else {
            Write-FAIL "$($check.Name): 未找到（可能需要重启终端）"
            $verifyResults += @{ Name = $check.Name; Status = "FAIL" }
        }
    } catch {
        Write-FAIL "$($check.Name): 未找到（可能需要重启终端）"
        $verifyResults += @{ Name = $check.Name; Status = "FAIL" }
    }
}

# ──────────────────────────────────────────────
# 第六步：后续建议
# ──────────────────────────────────────────────

Write-Step "第六步：后续操作建议"

# VS Code 插件推荐
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

# Docker 后续
Write-Host @"
  🐳 Docker 后续操作:
     Docker Desktop 安装后可能需要重启电脑。
     首次启动后，打开终端拉取 Redis 镜像:
       docker pull redis
       docker run -d --name redis -p 6379:6379 redis

"@

# 工作目录
$workspacePath = $gitConfig?.paths?.workspace ?? "$env:USERPROFILE\dev\workspace"
if (-not (Test-Path $workspacePath)) {
    New-Item -ItemType Directory -Path $workspacePath -Force -ErrorAction SilentlyContinue | Out-Null
    Write-OK "已创建工作目录: $workspacePath"
}

# ──────────────────────────────────────────────
# 汇总报告
# ──────────────────────────────────────────────

Write-Step "安装汇总报告"

Write-Host ""
Write-Host "  软件安装结果:" -ForegroundColor White
foreach ($r in $installResults) {
    $icon = switch ($r.Status) {
        "OK"   { "[✓]" }
        "SKIP" { "[—]" }
        "FAIL" { "[✗]" }
    }
    $color = switch ($r.Status) {
        "OK"   { "Green" }
        "SKIP" { "Yellow" }
        "FAIL" { "Red" }
    }
    Write-Host "    $icon $($r.Name)" -ForegroundColor $color
}

Write-Host ""
Write-Host "  环境验证结果:" -ForegroundColor White
foreach ($r in $verifyResults) {
    $icon = switch ($r.Status) {
        "OK"   { "[✓]" }
        "FAIL" { "[✗]" }
    }
    $color = switch ($r.Status) {
        "OK"   { "Green" }
        "FAIL" { "Red" }
    }
    $verStr = if ($r.Version) { " — $($r.Version)" } else { "" }
    Write-Host "    $icon $($r.Name)$verStr" -ForegroundColor $color
}

$failCount = ($installResults | Where-Object { $_.Status -eq "FAIL" }).Count
$okCount = ($installResults | Where-Object { $_.Status -eq "OK" }).Count
$skipCount = ($installResults | Where-Object { $_.Status -eq "SKIP" }).Count

Write-Host ""
Write-Host "  总计: $okCount 个新安装 | $skipCount 个已跳过 | $failCount 个失败" -ForegroundColor White

if ($failCount -gt 0) {
    Write-Host ""
    Write-WARN "存在安装失败的软件，请检查上述 [✗] 项目并手动安装。"
    Write-INFO "常见原因: 网络问题、winget 源临时不可用。可重新运行此脚本重试。"
}

Write-Host @"

  ✨ 配置完成！
  ⚠️  部分环境变量需要重启终端（或重启电脑）才能完全生效。
  ⚠️  Docker Desktop 首次使用需要启动 Docker 服务。

  小皮面板请手动下载安装: https://www.xp.cn
  Navicat 请自行获取安装: https://www.navicat.com.cn

"@ -ForegroundColor Cyan

Read-Host "按任意键退出..."
