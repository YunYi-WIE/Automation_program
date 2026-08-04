# 开发环境自动化配置脚本 — 设计文档

**日期：** 2026-08-04
**状态：** 已确认

---

## 概述

一个 PowerShell 脚本 (`setup.ps1`)，在新 Windows 电脑上一键完成 Java 开发环境的初始化，包括软件安装、环境变量配置和验证。

## 用户画像

- Java 开发为主（JDK 21 + Maven）
- 前端也会做（Node.js + VS Code）
- 使用小皮面板管理 MySQL，Navicat 管理数据库
- Docker 用于运行 Redis 等中间件
- 全部走 winget 默认路径安装

## 结构

```
工作环境配置/
├── setup.ps1          # 主脚本
├── config.json        # 用户偏好配置
└── README.md          # 使用说明
```

## 安装清单

| # | 软件 | Winget ID | 用途 |
|---|------|-----------|------|
| 1 | JDK 21 | `Oracle.JDK.21` | Java 开发 |
| 2 | Maven | `Apache.Maven` | 项目构建 |
| 3 | Git | `Git.Git` | 版本控制 |
| 4 | VS Code | `Microsoft.VisualStudioCode` | 前端/轻量编辑 |
| 5 | IntelliJ IDEA CE | `JetBrains.IntelliJIDEA.Community` | Java 主 IDE |
| 6 | Node.js LTS | `OpenJS.NodeJS.LTS` | 前端工具链 |
| 7 | Docker Desktop | `Docker.DockerDesktop` | 容器服务 |
| 8 | Notepad++ | `Notepad++.Notepad++` | 轻量文本编辑 |
| 9 | Windows Terminal | `Microsoft.WindowsTerminal` | 现代终端 |

### 手动安装（winget 未覆盖）

- 小皮面板（phpStudy）— 提示官网下载
- Navicat — 提示自行获取安装并激活

## 执行流程

### 第一步：环境检查
- winget 可用性检查
- 管理员权限提示（非必须，建议）

### 第二步：批量安装
- 逐个 winget install
- 每步检测是否已安装，已装则跳过
- 输出 [OK] / [SKIP] / [FAIL]

### 第三步：手动安装提示
- 暂停并显示小皮面板、Navicat 的下载指引

### 第四步：环境变量
- 读取注册表获取 JDK 路径 → 设置 `JAVA_HOME`
- 查找 Maven 路径 → 设置 `MAVEN_HOME`
- 追加到系统 Path
- 提示配置 Git user.name / user.email

### 第五步：验证
- `java -version`
- `mvn -v`
- `node -v`
- `git --version`
- `docker --version`

### 第六步：建议清单
- VS Code 推荐插件
- Docker 后续操作（`docker pull redis`）
- 创建 `~/dev/workspace` 目录

## 错误处理

- 单个安装失败不中断整体流程
- 最后汇总报告所有失败项
- 环境变量设置失败给出手动配置指引

## 原则

- **幂等** — 可安全重复执行
- **清晰** — 每步有明确的状态输出
- **非侵入** — 不改动已存在的配置
