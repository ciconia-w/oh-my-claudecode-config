# oh-my-claudecode Troubleshooting For Agents

适用范围：WSL/Linux 下的 oh-my-claudecode 配置与启动过程。

处理原则：
- 先做可写性和空间检查，再执行安装或认证。
- 默认假设当前会话不能输入 `sudo` 密码。
- 需要改文件、装依赖、修复环境时，不要选择只读分析角色。
- 多行 prompt 不要直接裸传给 `--agent-prompt`。

## 1. tmpfs 空间不足导致 codex 失败

### 问题描述
在 WSL/Linux 中，运行 codex 或相关子进程时失败，尤其是在多次重试或残留大量临时目录后。

### 错误信息
常见报错：
- `No space left on device`
- `ENOSPC`
- 临时目录创建失败，路径位于 `/run/user/<uid>/...`

### 根本原因
运行时临时文件落在 `/run/user/<uid>` 对应的 tmpfs 上。该挂载点空间通常较小，残留的 `codex-*` 或 `codex-linux-*` 目录会快速耗尽可用空间。

### 解决步骤（agent 可执行）
```bash
# 1) 检查 tmpfs 使用率
df -h /run/user/$UID 2>/dev/null || true

# 2) 查看残留目录
find /run/user/$UID -maxdepth 1 \( -name 'codex-*' -o -name 'codex-linux-*' \) -print 2>/dev/null || true

# 3) 优先使用仓库内清理脚本
bash /mnt/d/code/vibe/scripts/cleanup-tmpfs.sh

# 4) 若脚本不可用，手动清理
rm -rf /run/user/$UID/codex-* /run/user/$UID/codex-linux-* 2>/dev/null || true

# 5) 再次确认空间
df -h /run/user/$UID 2>/dev/null || true
```

### 预防措施
- 在启动长任务前先执行一次 `df -h /run/user/$UID`。
- 将 tmpfs 清理加入启动前钩子或定时任务。
- 连续失败且报错涉及临时目录时，优先排查空间，不要立刻重试同一命令。

## 2. `~/.config` 权限问题（root 拥有）

### 问题描述
配置工具时无法在 `~/.config` 或其子目录下写入文件，例如 `gh`、CLI token、状态文件等。

### 错误信息
真实报错样例：
- `mkdir: cannot create directory '/home/wxw/.config/gh': Permission denied`
- `uid=0 gid=0 drwxr-xr-x 755 /home/wxw/.config`

### 根本原因
`~/.config` 被错误地创建为 `root:root` 所有，当前用户虽然拥有家目录，但对该目录没有写权限。类似问题也可能出现在 `~/.local/share`。

### 解决步骤（agent 可执行）
```bash
# 1) 明确属主和权限
namei -om ~/.config 2>/dev/null || true
stat -c 'owner=%U:%G %A %a %n' ~/.config ~/.local ~/.local/share ~/.cache 2>/dev/null || true

# 2) 若有免密 sudo，直接修复
if sudo -n true 2>/dev/null; then
  sudo chown "$USER:$USER" ~/.config
  chmod 700 ~/.config
fi

# 3) 若没有免密 sudo，改走当前用户可写目录
if [ -w "$HOME/.cache" ]; then
  mkdir -p "$HOME/.cache/gh"
  chmod 700 "$HOME/.cache/gh"
  export GH_CONFIG_DIR="$HOME/.cache/gh"
else
  mkdir -p "/tmp/gh-config-$USER"
  chmod 700 "/tmp/gh-config-$USER"
  export GH_CONFIG_DIR="/tmp/gh-config-$USER"
fi

# 4) 验证替代目录可写
stat -c 'owner=%U:%G %A %a %n' "$GH_CONFIG_DIR"
touch "$GH_CONFIG_DIR/.write-test" && rm -f "$GH_CONFIG_DIR/.write-test"
```

### 预防措施
- 配置前先检查：`stat -c 'owner=%U:%G %A %a %n' ~/.config ~/.local/share ~/.cache`
- 不要用 `sudo` 运行会在用户家目录写配置的初始化命令。
- 为每个需要配置目录的工具准备显式的用户级 fallback，例如 `GH_CONFIG_DIR`。

## 3. agent 角色选择错误（`architect` 只读）

### 问题描述
任务明明需要安装、改文件或修复代码，却把执行任务交给了 `architect`，结果 agent 只能分析，不能真正落地。

### 错误信息
常见表现：
- `architect 无法执行 Write/Edit`
- agent 反复输出分析建议，但不创建、不修改任何文件
- 指令中明确标注该角色只负责分析、诊断、评审，而非实现

### 根本原因
`architect` 的职责是分析、方案设计、架构校验、根因诊断，不是写文件的执行角色。把实现型任务交给只读角色，会造成“看起来在工作，但环境没有变化”。

### 解决步骤（agent 可执行）
```text
决策规则：
1. 任务包含 “安装 / 修改文件 / 写脚本 / 修权限 / 落地实现 / 打补丁” 时，不要使用 architect。
2. 需要实际执行时，切换到可写执行角色，例如 executor / implementer / codex。
3. architect 仅用于：
   - 根因分析
   - 方案评审
   - 实现前的设计校验
   - 连续失败 3 次后的升级诊断
```

```bash
# 启动前先做人为检查：
printf '%s\n' "task=implementation => role must be writable"
```

### 预防措施
- 在任务分派前先判断目标是“分析”还是“执行”。
- 将角色选择写成固定规则：`analysis -> architect`，`implementation -> writable agent`。
- 如果 agent 连续只给建议不落地，先检查角色，不要先怀疑命令本身。

## 4. `--agent-prompt` 参数传递问题

### 问题描述
为 agent 传递 prompt 时，内容被截断、空格丢失、换行损坏，或者 shell 把 prompt 的一部分当成新命令执行。

### 错误信息
常见表现：
- agent 只收到 prompt 的第一行或前几个词
- shell 报 `command not found`
- CLI 报参数不完整、未知参数，或行为与预期 prompt 明显不一致

### 根本原因
`--agent-prompt` 往往承载长文本、多行内容和引号。若直接裸传，或经历 `cmd.exe -> wsl.exe -> bash -lc` 的多层转义，shell 会先吃掉换行、空格或引号，导致最终传给 CLI 的内容已经变形。

### 解决步骤（agent 可执行）
```bash
# 1) 先把 prompt 写入文件，避免多层转义
cat > /tmp/omc-agent-prompt.txt <<'EOF'
这里放完整的 agent prompt。
允许多行、引号和特殊字符。
EOF

# 2) 再由 bash 读取成单个变量
AGENT_PROMPT="$(cat /tmp/omc-agent-prompt.txt)"

# 3) 始终用双引号传参
claude-omc --agent-prompt "$AGENT_PROMPT"
```

```bash
# 4) 调试时先验证实际内容
printf '%s\n' "$AGENT_PROMPT"
printf 'length=%s\n' "${#AGENT_PROMPT}"
```

### 预防措施
- 不要使用未加引号的 `--agent-prompt $AGENT_PROMPT`。
- 不要把多行 prompt 直接硬编码进 `.cmd` 或复杂的一行命令。
- 优先采用“写入文件 -> 读入变量 -> 双引号传参”的固定模式。

## 5. `sudo` 需要密码，无法自动化

### 问题描述
agent 需要修权限或安装系统级依赖，但当前会话中的 `sudo` 会要求交互式密码，导致自动化流程中断。

### 错误信息
真实报错样例：
- `sudo: a terminal is required to read the password; either use the -S option to read from standard input or configure an askpass helper`
- `sudo: a password is required`

### 根本原因
agent 运行在非交互式上下文中，既没有 TTY，也不知道用户密码。此时任何依赖 `sudo` 输入密码的命令都无法自动完成。

### 解决步骤（agent 可执行）
```bash
# 1) 先探测是否具备免密 sudo
if sudo -n true 2>/dev/null; then
  echo "passwordless-sudo=yes"
else
  echo "passwordless-sudo=no"
fi
```

```text
2. 若输出为 `passwordless-sudo=no`，立即切换策略：
   - 不再重试需要 sudo 的命令
   - 改用用户级安装、用户级配置目录、用户级 PATH
   - 将真正需要 root 的步骤收敛为一条人工执行指令
```

```bash
# 3) 用户级替代路径示例
mkdir -p "$HOME/.local/bin" "$HOME/.cache"
chmod 700 "$HOME/.cache"
export PATH="$HOME/.local/bin:$PATH"
```

```text
4. 必须提权时，只输出明确的人工步骤，例如：
   sudo chown -R "$USER:$USER" ~/.config ~/.local/share
```

### 预防措施
- 所有安装脚本开头先执行 `sudo -n true`，不要等到中途失败才发现。
- 默认优先设计为用户级安装，不把系统级安装当成唯一方案。
- 把“需要人工输入 sudo 密码”的步骤显式拆成单独阶段，不要混在自动化主流程里。

## 最小排查顺序

```text
1. 先查 tmpfs：df -h /run/user/$UID
2. 再查目录权限：stat ~/.config ~/.local/share ~/.cache
3. 再查 sudo 模式：sudo -n true
4. 再查 agent 角色是否可写
5. 最后查 --agent-prompt 是否经过安全引用
```
