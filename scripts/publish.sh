#!/usr/bin/env bash
# 发布到 GitHub（首次发布、后续发版、fork 后改成自己的仓库，都是这一条）
#
#   bash scripts/publish.sh <GitHub用户名>/<仓库名> [新版本号]
#
# 前提：已在 GitHub 网页上建好同名的【公开】空仓库，且本机 git 能推送到 GitHub。
# 做了什么：
#   1. 把 install.sh / install.ps1 / README.md 里的仓库地址统一改成你的
#   2. （可选）写入新版本号到 VERSION —— 用户再执行一次安装命令就会显示 vX → vY
#   3. git commit 并 push 到 main
set -euo pipefail
cd "$(dirname "$0")/.."

NEW_REPO="${1:-}"
NEW_VER="${2:-}"
[[ "$NEW_REPO" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { echo "用法: bash scripts/publish.sh owner/repo [新版本号]"; exit 1; }

# 1. 替换仓库地址（占位符或上一个仓库名都会被替换）
CUR_REPO="$(sed -n 's/^REPO="\${SKILL_REPO:-\(.*\)}"$/\1/p' install.sh)"
[ -n "$CUR_REPO" ] || { echo "无法从 install.sh 读取当前仓库地址"; exit 1; }
if [ "$CUR_REPO" != "$NEW_REPO" ]; then
  for f in install.sh install.ps1 README.md; do
    OLD="$CUR_REPO" NEW="$NEW_REPO" perl -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/g' "$f"
  done
  echo "✓ 仓库地址：$CUR_REPO → $NEW_REPO"
fi

# 2. 版本号
if [ -n "$NEW_VER" ]; then
  printf '%s\n' "$NEW_VER" > VERSION
  echo "✓ 版本号：$NEW_VER"
fi
VER="$(tr -d '[:space:]' < VERSION)"

# 3. git 提交并推送
[ -d .git ] || git init -q
git branch -M main
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "release v$VER"
  echo "✓ 已提交 release v$VER"
fi
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "https://github.com/$NEW_REPO.git"
else
  git remote add origin "https://github.com/$NEW_REPO.git"
fi
git push -u origin main

cat <<EOF

✓ 已发布 v${VER}。把下面这一行发给任何人即可安装 / 更新：

  macOS / Linux:
    curl -fsSL https://raw.githubusercontent.com/$NEW_REPO/main/install.sh | bash

  Windows (PowerShell):
    irm https://raw.githubusercontent.com/$NEW_REPO/main/install.ps1 | iex

  或者直接对 AI 说一句：
    帮我安装这个 skill：https://github.com/$NEW_REPO
EOF
