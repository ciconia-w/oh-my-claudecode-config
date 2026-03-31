@echo off
setlocal
wsl.exe -e bash -lc "cd /mnt/d/code/vibe && exec claude-omc"
