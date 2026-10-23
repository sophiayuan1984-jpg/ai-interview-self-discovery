#!/usr/bin/env bash
# ai-interview-self-discovery —— 一键安装 / 更新（同一条命令，重复执行即更新）
#
#   安装 / 更新：curl -fsSL https://raw.githubusercontent.com/sophiayuan1984-jpg/ai-interview-self-discovery/main/install.sh | bash
#   卸载：      curl -fsSL https://raw.githubusercontent.com/sophiayuan1984-jpg/ai-interview-self-discovery/main/install.sh | bash -s -- --uninstall
#
# 可选环境变量：
#   SKILL_REPO=owner/repo     从哪个 GitHub 仓库安装（默认见下方 REPO）
#   SKILL_BRANCH=main         分支
#   SKILL_DIR=/path/skills    只安装到这个 skills 目录（默认自动检测本机已有的 Agent）
set -euo pipefail

NAME="ai-interview-self-discovery"
REPO="${SKILL_REPO:-sophiayuan1984-jpg/ai-interview-self-discovery}"
BRANCH="${SKILL_BRANCH:-main}"
ITEMS=(SKILL.md README.md VERSION LICENSE references tests)

MODE="install"
[ "${1:-}" = "--uninstall" ] && MODE="uninstall"

say() { printf '%s\n' "$*"; }
die() { printf '✗ %s\n' "$*" >&2; exit 1; }

# ---------- 1. 安装目标：本机已有哪些 Agent 就装到哪些 ----------
TARGETS=()
if [ -n "${SKILL_DIR:-}" ]; then
  TARGETS=("$SKILL_DIR")
else
  for agent in .workbuddy .codebuddy .claude .codex .cursor; do
    [ -d "$HOME/$agent" ] && TARGETS+=("$HOME/$agent/skills")
  done
  [ ${#TARGETS[@]} -eq 0 ] && TARGETS=("$HOME/.claude/skills")
fi

# ---------- 2. 卸载 ----------
if [ "$MODE" = "uninstall" ]; then
  removed=0
  for t in "${TARGETS[@]}"; do
    d="$t/$NAME"
    if [ -d "$d" ] && [ -f "$d/SKILL.md" ]; then
      rm -rf "$d"; say "✓ 已卸载 $d"; removed=1
    fi
  done
  [ "$removed" = 1 ] || say "未发现已安装的 $NAME"
  exit 0
fi

# ---------- 3. 获取源文件：本地仓库优先，否则从 GitHub 下载 ----------
SRC=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
  here="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  [ -f "$here/SKILL.md" ] && SRC="$here"
fi

if [ -z "$SRC" ]; then
  PLACEHOLDER="__""REPO__"
  [ "$REPO" = "$PLACEHOLDER" ] && die "仓库地址尚未设置：请用 SKILL_REPO=owner/repo 指定，或先运行 scripts/publish.sh"
  command -v curl >/dev/null 2>&1 || die "需要 curl"
  command -v tar  >/dev/null 2>&1 || die "需要 tar"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  say "→ 下载 $REPO@$BRANCH ..."
  curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH" | tar -xz -C "$TMP" \
    || die "下载失败，请检查仓库是否公开、分支是否存在：$REPO@$BRANCH"
  SRC="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [ -f "$SRC/SKILL.md" ] || die "仓库根目录没有 SKILL.md"
fi

NEW_VER="$(tr -d "[:space:]" 2>/dev/null < "$SRC/VERSION" || echo unknown)"

# ---------- 4. 原子替换安装 ----------
for t in "${TARGETS[@]}"; do
  mkdir -p "$t"
  dest="$t/$NAME"

  # 防呆：源目录就是安装目录（直接 clone 到 skills 下）时不覆盖，改用 git pull 更新
  if [ -d "$dest" ] && [ "$(cd "$dest" && pwd)" = "$SRC" ]; then
    say "• 跳过 ${dest}（它就是源目录，请在该目录用 git pull 更新）"
    continue
  fi

  old="$(tr -d "[:space:]" 2>/dev/null < "${dest}/VERSION" || true)"
  stage="$t/.$NAME.tmp.$$"
  rm -rf "$stage"; mkdir -p "$stage"
  for f in "${ITEMS[@]}"; do
    [ -e "$SRC/$f" ] && cp -R "$SRC/$f" "$stage/"
  done
  rm -rf "$dest"
  mv "$stage" "$dest"

  if [ -z "${old}" ]; then
    say "✓ 已安装 v${NEW_VER} → $dest"
  elif [ "${old}" = "${NEW_VER}" ]; then
    say "✓ 已是最新 v${NEW_VER}（已重新同步）→ $dest"
  else
    say "✓ 已更新 v${old} → v${NEW_VER} → $dest"
  fi
done

say ""
say "新开一个对话，说「面试我」或「我想看看自己适不适合做 XX 岗位」即可开始。"
