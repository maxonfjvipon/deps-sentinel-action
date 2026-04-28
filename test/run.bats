#!/usr/bin/env bats
# SPDX-FileCopyrightText: Copyright (c) 2026 Max Trunnikov
# SPDX-License-Identifier: MIT

SCRIPT="${BATS_TEST_DIRNAME}/../src/run.sh"
FAKE="${BATS_TEST_DIRNAME}/fake/gh"

defaults() {
  export FAKE_RULTOR="false"
  export FAKE_PR_COMMENTS=""
  export INPUT_BOT_LOGINS="renovate[bot]
dependabot[bot]"
  export INPUT_OWNER="maxonfjvipon"
  export INPUT_MERGE_METHOD="merge"
  export INPUT_RULTOR="false"
  export INPUT_REQUIRED_CHECKS=""
  export INPUT_DRY_RUN="false"
  export GITHUB_REPOSITORY="owner/repo"
  export GITHUB_BOT_TOKEN="bot-token"
}

@test "skips when there are no open dependency bot pull requests" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST=""
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  rm -rf "$tmp"
  [[ "$output" == *"No open dependency bot pull requests found"* ]]
}

@test "merges dependabot pull request when all checks are green" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export INPUT_BOT_LOGINS="dependabot[bot]"
  export FAKE_PR_LIST="99"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"SUCCESS"}]'
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" == *"pr merge 99"* ]]
}

@test "merges pull request when all checks are green" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"SUCCESS"}]'
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" == *"pr merge 42"* ]]
}

@test "posts rultor merge when rultor yml exists and checks are green" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"SUCCESS"}]'
  export FAKE_RULTOR="true"
  export INPUT_RULTOR="auto"
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" == *"@rultor merge"* ]]
}

@test "notifies owner when ci checks have failed" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"FAILURE"}]'
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" == *"@maxonfjvipon"* ]]
}

@test "does not notify twice when already commented on failure" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"FAILURE"}]'
  export FAKE_PR_COMMENTS="<!-- deps-sentinel-action: ci-failure -->"
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  rm -rf "$tmp"
  [[ "$output" == *"already notified"* ]]
}

@test "skips pull request when checks are still pending" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"IN_PROGRESS","conclusion":null}]'
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  rm -rf "$tmp"
  [[ "$output" == *"checks still pending"* ]]
}

@test "does not merge in dry run mode" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"SUCCESS"}]'
  export INPUT_DRY_RUN="true"
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" != *"pr merge"* ]]
}

@test "only considers required checks when required checks are specified" {
  tmp=$(mktemp -d)
  cp "$FAKE" "$tmp/gh" && chmod +x "$tmp/gh"
  defaults
  export FAKE_GH_LOG="$tmp/gh.log"
  export FAKE_PR_LIST="42"
  export FAKE_PR_CHECKS='[{"name":"build","state":"COMPLETED","conclusion":"SUCCESS"},{"name":"lint","state":"COMPLETED","conclusion":"FAILURE"}]'
  export INPUT_REQUIRED_CHECKS="build"
  PATH="$tmp:$PATH" run bash "$SCRIPT"
  log=$(cat "$tmp/gh.log" 2>/dev/null || echo "")
  rm -rf "$tmp"
  [[ "$log" == *"pr merge 42"* ]]
}
