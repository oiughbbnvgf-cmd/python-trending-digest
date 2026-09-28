#!/usr/bin/env bash
#
# 提交并推送 /pydigest 的产出。
#
#   ./scripts/publish.sh              # 自动生成提交信息（取最新报告日期）
#   ./scripts/publish.sh "自定义信息"  # 自己写
#   ./scripts/publish.sh --dry-run     # 只看会发生什么，不提交
#
# 只依赖 git 和 POSIX 工具，不需要 gh。

set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
MESSAGE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) MESSAGE="$arg" ;;
  esac
done

# ── 前置检查 ──────────────────────────────────────────────

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "错误：不在 git 仓库里" >&2; exit 1
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "错误：当前分支是 '$BRANCH'，不是 main" >&2
  echo "      先合并再发，或手动改分支名。" >&2
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "错误：没有 origin 远程" >&2; exit 1
fi

# ── 待提交内容 ────────────────────────────────────────────

git add -A

STAGED=$(git diff --cached --name-only)
ADDED=""

if [ -n "$STAGED" ]; then
  echo "待提交："
  git diff --cached --stat
  echo
  ADDED=$(git diff --cached --name-only --diff-filter=A)

  HTML_ADDED=$(echo "$ADDED" | grep -c '\.html$' || true)
  if [ "$HTML_ADDED" -gt 0 ]; then
    echo "注意：新增了 $HTML_ADDED 个 HTML。reports/ 下的已在 .gitignore 中，"
    echo "      所以它们多半在别的目录——确认一下是否真要入库。"
    echo
  fi
else
  echo "工作区无改动。"
fi

# 有未推送的提交也要推，不能因为「没东西可提交」就跳过
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ -z "$STAGED" ] && [ "$AHEAD" -eq 0 ]; then
  echo "没有改动，也没有未推送的提交。无需操作。"
  exit 0
fi
if [ "$AHEAD" -gt 0 ] && [ -z "$STAGED" ]; then
  echo "有 $AHEAD 个提交待推送。"
  echo
fi

# ── 提交信息 ──────────────────────────────────────────────

if [ -n "$STAGED" ] && [ -z "$MESSAGE" ]; then
  # 只在确实新增了报告时才用日期起头，否则会写出与实际内容不符的信息
  NEW_MD=$(echo "$ADDED" | grep '^reports/digest_.*\.md$' | head -1 || true)
  if [ -n "$NEW_MD" ]; then
    DATE=$(basename "$NEW_MD" .md | sed 's/^digest_//')
    MESSAGE="docs: ${DATE} Python 月榜报告"
  else
    echo "本次没有新增报告，自动生成的信息会是 'chore: 更新'。"
    echo "建议自己写：./scripts/publish.sh \"你的信息\""
    echo
    MESSAGE="chore: 更新"
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "── dry run，不会真的提交 ──"
  [ -n "$MESSAGE" ] && echo "提交信息：$MESSAGE"
  exit 0
fi

# ── 提交并推送 ────────────────────────────────────────────

if [ -n "$STAGED" ]; then
  git commit -q -m "$MESSAGE" -m "Co-Authored-By: Claude Code <noreply@anthropic.com>"
fi
git push -q origin main

echo "已推送 → $(git remote get-url origin)"
git log -1 --format='%h  %s'
