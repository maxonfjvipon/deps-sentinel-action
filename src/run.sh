#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2026 Max Trunnikov
# SPDX-License-Identifier: MIT
set -e -o pipefail

FAILURE_MARKER="<!-- deps-sentinel-action: ci-failure -->"

use_rultor() {
  case "$INPUT_RULTOR" in
    true)  return 0 ;;
    false) return 1 ;;
    *)     gh api "repos/${GITHUB_REPOSITORY}/contents/.rultor.yml" &>/dev/null ;;
  esac
}

filter_checks() {
  local checks="$1"
  if [[ -z "$INPUT_REQUIRED_CHECKS" ]]; then
    echo "$checks"
    return
  fi
  echo "$checks" | jq --arg names "$INPUT_REQUIRED_CHECKS" \
    '($names | split(",") | map(ltrimstr(" ") | rtrimstr(" "))) as $req |
     map(select(.name | IN($req[])))'
}

any_red() {
  local checks="$1"
  local count
  count=$(echo "$checks" | jq '[.[] | select(
    ((.state | ascii_downcase) == "completed") and
    ((.conclusion | ascii_downcase) | IN("failure","timed_out","cancelled","action_required"))
  )] | length')
  [[ "$count" != "0" ]]
}

all_green() {
  local checks="$1"
  local total pending
  total=$(echo "$checks" | jq 'length')
  [[ "$total" == "0" ]] && return 1
  pending=$(echo "$checks" | jq '[.[] | select((.state | ascii_downcase) != "completed")] | length')
  [[ "$pending" == "0" ]]
}

already_commented() {
  local pr="$1"
  GH_TOKEN="$GITHUB_BOT_TOKEN" gh pr view "$pr" --json comments \
    --jq '.comments[].body' 2>/dev/null | grep -qF "$FAILURE_MARKER"
}

notify_failure() {
  local pr="$1"
  if already_commented "$pr"; then
    echo "PR #${pr}: already notified, skipping"
    return
  fi
  echo "PR #${pr}: notifying @${INPUT_OWNER} about CI failure"
  [[ "$INPUT_DRY_RUN" == "true" ]] && return
  GH_TOKEN="$GITHUB_BOT_TOKEN" gh pr comment "$pr" \
    --body "@${INPUT_OWNER}, CI is failing on this pull request
${FAILURE_MARKER}"
}

merge_pr() {
  local pr="$1"
  if use_rultor; then
    echo "PR #${pr}: posting @rultor merge"
    [[ "$INPUT_DRY_RUN" == "true" ]] && return
    gh pr comment "$pr" --body "@rultor merge"
  else
    echo "PR #${pr}: merging directly (${INPUT_MERGE_METHOD})"
    [[ "$INPUT_DRY_RUN" == "true" ]] && return
    gh pr merge "$pr" "--${INPUT_MERGE_METHOD}"
  fi
}

prs=""
while IFS= read -r login; do
  [[ -z "$login" ]] && continue
  result=$(gh pr list --author "$login" --state open --json number --jq '.[].number')
  prs="$prs $result"
done <<< "$INPUT_BOT_LOGINS"
prs=$(echo "$prs" | xargs -n1 | sort -u)

if [[ -z "$prs" ]]; then
  echo "No open dependency bot pull requests found"
  exit 0
fi

for pr in $prs; do
  echo "PR #${pr}: checking CI status"
  raw=$(gh pr checks "$pr" --json name,state,conclusion 2>/dev/null || true)
  checks=$(filter_checks "$raw")
  if any_red "$checks"; then
    notify_failure "$pr"
  elif all_green "$checks"; then
    merge_pr "$pr"
  else
    echo "PR #${pr}: checks still pending, skipping"
  fi
done
