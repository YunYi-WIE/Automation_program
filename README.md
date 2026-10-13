# Java 开发环境一键配置

适用于 Windows 10/11 新电脑，一键安装 Java 开发常用工具并配置 `JAVA_HOME` / `MAVEN_HOME` 环境变量。

## 一键使用

### 方式一：命令行（推荐，可先预览）

```powershell
# 1) 先演练一遍，看看会装什么、会改哪些环境变量（不会真的安装任何东西）
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -DryRun

# 2) 确认无误后正式执行（会在需要时弹出 UAC 提权确认）
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```

### 方式二：右键运行

**右键 `setup.ps1` → 以管理员身份运行**，或直接双击后在 UAC 弹窗点「是」。

> 💡 脚本是**幂等**的——已安装的软件会自动跳过，可安全重复执行多次。
>
> ⚠️ 如果双击后窗口**一闪而过**、什么都没发生，是系统的执行策略（ExecutionPolicy）禁止运行脚本。
> 请改用上面的命令行方式，或参见 [常见问题](#脚本一闪而过什么都没发生)。

## 安装内容

| 类别 | 软件 |
|------|------|
| Java 开发 | JDK 21、Apache Maven |
| IDE | IntelliJ IDEA Community、VS Code |
| 前端 | Node.js LTS + npm |
| 版本控制 | Git + 配置用户名/邮箱 |
| 容器 | Docker Desktop |
| 编辑器 | Notepad++ |
| 终端 | Windows Terminal |

### 需要手动安装

- 🟡 **小皮面板 (phpStudy)** — [官网下载](https://www.xp.cn)（MySQL 管理）
- 🟡 **Navicat** — [官网](https://www.navicat.com.cn)（数据库客户端，付费）

## 命令行参数

| 参数 | 说明 |
|------|------|
| `-DryRun` | 演练模式：只打印将要执行的操作，**不安装软件、不修改环境变量**，用于安全预览 |
| `-NonInteractive` | 非交互模式：不等待任何按键输入，适合远程 / 无人值守执行 |
| `-SkipManualReminders` | 跳过「需要手动安装的软件」提示 |
| `-LogPath <路径>` | 把完整过程写入日志文件，便于事后排查（例：`-LogPath .\setup.log`） |

组合示例：

```powershell
# 无人值守 + 记录日志
powershell -ExecutionPolicy Bypass -File .\setup.ps1 -NonInteractive -SkipManualReminders -LogPath C:\setup.log
```

## 自定义配置

编辑 `config.json` 可以预设 Git 用户信息和常用目录：

```json
{
  "git": {
    "userName": "Zhang San",
    "userEmail": "zhangsan@example.com"
  },
  "paths": {
    "workspace": "~/dev/workspace"
  }
}
```

- 留空则改为交互式询问（`-NonInteractive` 时保持为空并跳过）。
- `workspace` 支持 `~`（用户目录）与环境变量写法，会自动展开。

## 执行流程

1. **环境检查** — winget 可用性、PowerShell 版本、管理员权限（非管理员时会询问是否提权重启）
2. **批量安装** — 逐个 winget 安装，已装跳过；Docker 会额外检查 CPU 虚拟化
3. **手动提示** — 小皮面板、Navicat 下载指引
4. **环境变量** — 自动查找并设置 `JAVA_HOME`、`MAVEN_HOME`、系统 `Path`
5. **Git 配置** — 设置 `user.name` / `user.email`
6. **验证** — 运行 `java -version`、`mvn -v`、`node -v`、`git --version`、`docker --version`
7. **汇总报告** — 输出每个软件的成功 / 跳过 / 失败状态

## 常见问题

### 脚本一闪而过、什么都没发生？

Windows 默认执行策略（`Restricted`）禁止运行 `.ps1` 文件。三种解法（任选其一）：

```powershell
# 解法 1：单次绕过（最省事，不改系统设置）
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# 解法 2：只对当前用户放开（推荐长期使用）
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# 解法 3：临时会话放开
Set-ExecutionPolicy -Scope Process Bypass
```

### 中文显示成乱码？

`setup.ps1` **必须以「UTF-8 with BOM」保存**。

Windows PowerShell 5.1 对没有 BOM 的文件会按系统 ANSI 代码页（简体中文为 GBK）解码，导致中文变成乱码、字符串引号错位，进而报出大量「意外的标记」语法错误。

若用 VS Code 编辑：右下角编码 → `Save with Encoding` → **UTF-8 with BOM**。

### 为什么某些软件安装失败？

一般是 winget 源或网络问题，重新运行脚本即可重试。也可以手动 `winget install <软件ID>`，或加上 `--source winget` 指定官方源。

### 环境变量没生效？

重新打开终端窗口即可，或重启电脑。脚本已在本会话内刷新 `Path`，但已经打开的其它终端不会自动更新。

### 提示「未以管理员身份运行」/ 环境变量写入失败？

写入**系统级**环境变量（`JAVA_HOME` / `MAVEN_HOME` / 系统 `Path`）需要管理员权限。
非管理员运行时脚本会先询问是否自动提权重启；若选择继续，则只跳过系统级变量写入，其余步骤照常。

### git clone / push 报 `schannel: AcquireCredentialsHandle failed: SEC_E_NO_CREDENTIALS`？

这是 Git for Windows 默认走 Windows 安全通道（schannel）取凭据失败导致的，改用 Git 自带的 OpenSSL 后端即可：

```powershell
git config --global http.sslBackend openssl
```

### 能指定安装到 D 盘吗？

winget 使用软件默认安装路径，无法指定盘符。这些开发工具不大，装在 C 盘无影响。
若 JDK 装在非默认位置，脚本会通过注册表 `HKLM:\SOFTWARE\JavaSoft\JDK` 自动定位。

## 目录结构

```
Automation_program/
├── setup.ps1          # 主脚本（UTF-8 with BOM）
├── config.json        # 用户偏好配置
├── README.md          # 使用说明
└── docs/
    └── design.md      # 设计文档
```

## 开发说明（修改本脚本时请注意）

1. **编码**：`setup.ps1` 必须保存为 **UTF-8 with BOM**，否则 Windows PowerShell 5.1 会解析失败。
2. **兼容性**：脚本声明 `#Requires -Version 5.1`，因此**不能使用 PowerShell 7 专有语法**：
   - ❌ 空合并运算符 `??`、`??=`
   - ❌ 空条件成员访问 `?.`（组合使用时会解析失败）
   - ❌ 三元运算符 `? :`
   - ✅ 改用 `if / else` 与 `Get-JsonValue` 辅助函数（见脚本内实现）
3. **自检语法**（改完跑一遍，应为 0 错误）：

   ```powershell
   $e = $null
   [System.Management.Automation.Language.Parser]::ParseFile(
       (Resolve-Path .\setup.ps1).Path, [ref]$null, [ref]$e) | Out-Null
   $e.Count
   ```

4. **安全测试**：用 `-DryRun -NonInteractive` 跑通全流程，不会产生任何副作用。
