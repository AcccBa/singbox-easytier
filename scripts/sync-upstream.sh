#!/bin/bash
# 三条上游的统一同步入口（2026-10-19 起本仓为单仓；原 GitHub fork 关系已被可见性变更剥离，
# 没有 "Sync fork" 按钮，只能 subtree pull / 依赖 bump）。
#   status    只读报告（默认）
#   singbox   git subtree pull --prefix=sing-box  https://github.com/reF1nd/sing-box reF1nd-testing
#   sfa       git subtree pull --prefix=sfa       https://github.com/reF1nd/sing-box-for-android dev
#   easytier  只读：当前 go.mod pin vs 上游最新 release/commit，并打印要改的那一行
# 原则：冲突即停（列冲突文件后 merge --abort 回干净），**永不 push**，同步后必须跑回归门。
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1
LOG="$HOME/.local/state/logs/singbox-easytier-sync.log"; mkdir -p "$(dirname "$LOG")"
ALERT="/tmp/singbox-easytier-sync-alert.txt"
say(){ echo "$@" | tee -a "$LOG"; }
SB_URL="https://github.com/reF1nd/sing-box"; SB_BR="reF1nd-testing"
SFA_URL="https://github.com/reF1nd/sing-box-for-android"; SFA_BR="dev"
ET_MOD="github.com/easytier/easytier/easytier-go"

need_clean(){
  if [ -n "$(git status --porcelain | head -3)" ]; then
    say "FATAL: 工作区不干净，先提交或还原再同步"; return 1
  fi
}
behind_of(){ # $1=remote $2=branch
  timeout 600 git fetch -q "$1" "$2" >>"$LOG" 2>&1 || { say "FATAL: fetch $1/$2 失败"; return 1; }
  timeout 60 git fetch -q "$1" "+refs/heads/$2:refs/remotes/$1/$2" >>"$LOG" 2>&1
  echo "$(git rev-list --count "HEAD..$1/$2" 2>/dev/null)"
}
do_subtree(){ # $1=prefix $2=url $3=branch $4=label
  need_clean || return 1
  if ! git remote get-url "$4" >/dev/null 2>&1; then git remote add "$4" "$2"; fi
  local n; n=$(behind_of "$4" "$3") || return 1
  [ -z "$n" ] && { say "FATAL: 取不到 $4/$3 的落后数"; return 1; }
  say "[$1] 距 $4/$3 落后 $n 个提交"
  if [ "$n" = 0 ]; then say "[$1] 无需同步"; return 0; fi
  git log --oneline "HEAD..$4/$3" | head -15 | sed 's/^/    /' | tee -a "$LOG"
  say "[$1] 执行 subtree pull ..."
  if timeout 1800 git subtree pull --prefix="$1" "$2" "$3" --no-edit >>"$LOG" 2>&1; then
    say "[$1] 合并成功（未 push）。验收后：git push origin HEAD"
    say "        随后必跑：gh workflow run regression.yml --repo AcccBa/singbox-easytier --ref main"
    return 0
  fi
  local files; files=$(git diff --name-only --diff-filter=U | head -10)
  say "[$1] 冲突即停，未自动解。冲突文件："
  echo "$files" | sed 's/^/    /' | tee -a "$LOG"
  if [ -f .git/MERGE_HEAD ]; then git merge --abort; say "[$1] 已 merge --abort，工作树回干净"; fi
  echo "$(date -Is) subtree 冲突 $1 ($4/$3)" >> "$ALERT"
  return 1
}
easytier_report(){
  local cur; cur=$(grep -m1 -oE "${ET_MOD} v[^ ]+" sing-box/go.mod | awk '{print $2}')
  say "easytier 是**依赖**，不是本仓源码：sing-box/go.mod 钉 ${cur:-未找到}"
  local latest rel
  rel=$(timeout 60 gh api repos/EasyTier/easytier/releases --jq '.[0].tag_name' 2>/dev/null)
  latest=$(timeout 60 gh api "repos/EasyTier/easytier/commits?per_page=1" --jq '.[0].sha[0:12]' 2>/dev/null)
  say "上游最新 release=${rel:-取不到}；最新 commit=${latest:-取不到}（需代理与 gh 登录）"
  say "要 bump 就改这一行：  ${ET_MOD} v0.0.0-<UTC时间>-<新 commit 前12位>"
  say "本仓已无本地 Go 工具链 ⇒ bump 要么人工改 go.mod 后交给 CI 验证，要么在容器里跑 go get。"
  say "注意：预编译内核在 easytier-go/internal/artifact/easytier_core.wasm 里随模块交付，无需 Rust。"
}
case "${1:-status}" in
  status)
    need_clean || exit 1
    git remote get-url sb >/dev/null 2>&1 || git remote add sb "$SB_URL"
    git remote get-url sfaup >/dev/null 2>&1 || git remote add sfaup "$SFA_URL"
    say "== 同步状态 $(date -Is) =="
    say "sing-box/ ← sb/$SB_BR 落后 $(behind_of sb "$SB_BR" || echo '?')"
    say "sfa/      ← sfaup/$SFA_BR 落后 $(behind_of sfaup "$SFA_BR" || echo '?')"
    easytier_report ;;
  singbox) do_subtree sing-box "$SB_URL" "$SB_BR" sb ;;
  sfa)     do_subtree sfa "$SFA_URL" "$SFA_BR" sfaup ;;
  easytier) easytier_report ;;
  *) echo "用法: $0 [status|singbox|sfa|easytier]"; exit 2 ;;
esac
