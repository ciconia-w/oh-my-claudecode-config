# oh-my-claudecode 配置

跨平台 oh-my-claudecode 配置仓库，支持 agent 自动复刻。

## 快速开始

```bash
git clone <repo-url> ~/.omc-config
cd ~/.omc-config
./scripts/cleanup-tmpfs.sh  # 清理空间
```

## 目录结构

- `.claude/` - Claude 配置和规划文档
- `scripts/` - 自动化脚本
- `docs/` - 故障排查文档
- `start-*.cmd` - 启动脚本

## Agent 指令

查看 `docs/TROUBLESHOOTING.agent.md` 了解常见问题和解决方案。
