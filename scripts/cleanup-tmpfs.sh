#!/bin/bash
# 自动清理 tmpfs 空间，避免 codex 运行失败

echo "Cleaning tmpfs space..."
rm -rf /run/user/*/codex-linux-* 2>/dev/null || true
df -h /run/user/$UID/ 2>/dev/null || echo "tmpfs not found"
echo "Cleanup complete"
