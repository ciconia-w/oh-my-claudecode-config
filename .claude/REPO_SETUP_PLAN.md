# oh-my-claudecode 配置仓库规划

## 目标
让 agent 能够自动复刻和配置 oh-my-claudecode 环境，支持跨平台。

## 仓库结构

```
oh-my-claudecode-config/
├── README.agent.md          # Agent 可读的安装指令
├── setup.sh                 # 自动安装脚本
├── .claude/
│   ├── CLAUDE.md           # 项目指令
│   └── plans/              # 规划文档
│       └── multi-cli-collaboration.md
├── plugins/
│   └── omc/
│       └── src/
│           ├── utils/
│           │   └── progress-display.ts
│           └── team/
│               └── task-persistence.ts
├── scripts/
│   ├── detect-platform.sh  # 平台检测
│   ├── install-deps.sh     # 依赖安装
│   └── configure-env.sh    # 环境配置
├── docs/
│   ├── TROUBLESHOOTING.md  # 故障排查
│   └── KNOWN_ISSUES.md     # 已知问题
└── examples/
    └── start-wsl-claude-omc.cmd
```

## 平台检测逻辑

```bash
# detect-platform.sh
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
  PLATFORM="wsl"
elif [ "$(uname)" = "Darwin" ]; then
  PLATFORM="macos"
elif [ -f /etc/os-release ]; then
  . /etc/os-release
  if [ "$ID" = "deepin" ]; then
    PLATFORM="deepin"
  else
    PLATFORM="linux"
  fi
else
  PLATFORM="unknown"
fi
```

## Agent 可读安装指令 (README.agent.md)

```markdown
# AGENT SETUP PROTOCOL

## Prerequisites Check
- [ ] Claude Code CLI installed
- [ ] Git available
- [ ] Shell access (bash/zsh)

## Installation Steps

### 1. Clone Repository
```bash
git clone <repo-url> ~/.omc-config
cd ~/.omc-config
```

### 2. Run Setup
```bash
./setup.sh
```

### 3. Verify Installation
```bash
omc --version
claude --version
```

## Platform-Specific Notes

### WSL
- tmpfs space: 781M default, may need cleanup
- sudo may require password
- Use ~/.cache for configs if ~/.config is root-owned

### macOS
- Use Homebrew for dependencies
- XDG_CONFIG_HOME defaults to ~/.config

### Linux/Deepin
- Check package manager (apt/yum/pacman)
- Verify user permissions on ~/.config

## Troubleshooting Decision Tree

```
Installation fails?
├─ Permission denied on ~/.config?
│  └─ Use ~/.cache/gh-config instead
├─ tmpfs full?
│  └─ Run: rm -rf /run/user/*/codex-*
├─ Command not found?
│  └─ Check PATH includes ~/.local/bin
└─ Network timeout?
   └─ Retry with --timeout 600000
```
```

## 自动安装脚本 (setup.sh)

```bash
#!/bin/bash
set -e

# 检测平台
source scripts/detect-platform.sh

echo "Platform: $PLATFORM"

# 安装依赖
case $PLATFORM in
  wsl|linux|deepin)
    bash scripts/install-deps.sh linux
    ;;
  macos)
    bash scripts/install-deps.sh macos
    ;;
  *)
    echo "Unsupported platform"
    exit 1
    ;;
esac

# 配置环境
bash scripts/configure-env.sh

echo "Setup complete"
```

## 已知问题记录 (KNOWN_ISSUES.md)

```markdown
# Known Issues

## 1. tmpfs 磁盘空间不足
**Platform**: WSL, Linux
**Error**: `No space left on device`
**Solution**: `rm -rf /run/user/*/codex-linux-*`
**Prevention**: 定期清理或增加 tmpfs 大小

## 2. ~/.config 权限问题
**Platform**: WSL
**Error**: `Permission denied` on ~/.config
**Root Cause**: 目录归 root 所有
**Solution**: 使用 ~/.cache 替代或修复权限

## 3. Agent 角色选择错误
**Error**: architect 无法执行 Write/Edit
**Solution**: 使用 executor 角色执行实现任务

## 4. 后台任务超时
**Error**: Task timeout
**Solution**: 增加 --timeout 参数到 600000 (10分钟)
```

## 配置文件清单

### 必需文件
- `.claude/CLAUDE.md` - 项目指令和协作规则
- `plugins/omc/src/utils/progress-display.ts` - 进度显示工具
- `plugins/omc/src/team/task-persistence.ts` - 持久化策略

### 可选文件
- `.claude/plans/multi-cli-collaboration.md` - 协作模式设计
- `scripts/start-wsl-claude-omc.cmd` - Windows 启动脚本

## 下一步行动

1. 创建 GitHub 仓库
2. 复制配置文件到仓库
3. 编写 setup.sh 脚本
4. 测试跨平台安装
5. 编写 README.agent.md

