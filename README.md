# Java 开发环境一键配置

适用于 Windows 10/11 新电脑，一键安装 Java 开发常用工具和配置环境变量。

## 一键使用

**右键 `setup.ps1` → 以管理员身份运行**（推荐），或直接双击后在 UAC 弹窗点「是」。

> 💡 脚本是**幂等**的——已安装的软件会自动跳过，可安全重复执行多次。

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

## 执行流程

1. **环境检查** — winget 可用性、管理员权限
2. **批量安装** — 逐个 winget 安装，已装跳过
3. **手动提示** — 小皮面板、Navicat 下载指引
4. **环境变量** — 自动查找并设置 `JAVA_HOME`、`MAVEN_HOME`、`Path`
5. **验证** — 运行 `java -version`、`mvn -v` 等验证
6. **后续建议** — VS Code 插件推荐、Docker 操作提醒

## 常见问题

**Q: 为什么某些软件安装失败？**
A: 一般是 winget 源或网络问题，重新运行脚本即可重试。也可以手动 `winget install <软件ID>`。

**Q: 环境变量没生效？**
A: 重新打开终端窗口即可，或重启电脑。

**Q: 能指定安装到 D 盘吗？**
A: winget 使用软件默认安装路径，无法指定盘符。这些开发工具不大，装在 C 盘无影响。
