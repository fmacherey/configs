#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SCRIPT="$REPO_DIR/install.sh"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local test_name="$3"

  if printf '%s' "$haystack" | grep -Fq -- "$needle"; then
    pass "$test_name"
  else
    echo "  expected to find: $needle"
    fail "$test_name"
  fi
}

assert_is_symlink_to() {
  local path="$1"
  local expected_target="$2"
  local test_name="$3"

  if [[ ! -L "$path" ]]; then
    echo "  expected symlink but found: $path"
    fail "$test_name"
    return
  fi

  local actual_target
  actual_target="$(readlink "$path")"

  if [[ "$actual_target" == "$expected_target" ]]; then
    pass "$test_name"
  else
    echo "  expected target: $expected_target"
    echo "  actual target:   $actual_target"
    fail "$test_name"
  fi
}

copy_item_if_present() {
  local src="$1"
  local dst="$2"

  if [[ -L "$src" || -e "$src" ]]; then
    if [[ -d "$src" ]]; then
      cp -R "$src" "$dst"
    else
      cp "$src" "$dst"
    fi
  fi
}

run_test_help_output() {
  local out
  out="$(bash "$INSTALL_SCRIPT" --help)"

  assert_contains "$out" "--install-vscode-extensions" "help includes extensions option"
  assert_contains "$out" "--dryrun" "help includes dryrun option"
}

run_test_dryrun_table() {
  local tmp_home out
  tmp_home="$(mktemp -d)"

  out="$(HOME="$tmp_home" bash "$INSTALL_SCRIPT" --dryrun)"

  assert_contains "$out" "TYPE" "dryrun prints TYPE column"
  assert_contains "$out" "file" "dryrun includes file row"
  assert_contains "$out" "dir" "dryrun includes dir row"
  assert_contains "$out" "settings.json" "dryrun includes vscode settings mapping"

  rm -rf "$tmp_home"
}

run_test_install_creates_symlinks() {
  local tmp_home
  tmp_home="$(mktemp -d)"

  HOME="$tmp_home" bash "$INSTALL_SCRIPT" --install >/dev/null

  assert_is_symlink_to "$tmp_home/.zshrc" "$REPO_DIR/.zshrc" "install links .zshrc"
  if [[ -L "$REPO_DIR/.vimrc" || -e "$REPO_DIR/.vimrc" ]]; then
    assert_is_symlink_to "$tmp_home/.vimrc" "$REPO_DIR/.vimrc" "install links .vimrc"
  else
    if [[ ! -e "$tmp_home/.vimrc" && ! -L "$tmp_home/.vimrc" ]]; then
      pass "install skips missing .vimrc source"
    else
      echo "  expected .vimrc to be skipped when source is missing"
      fail "install skips missing .vimrc source"
    fi
  fi
  assert_is_symlink_to "$tmp_home/.gitconfig" "$REPO_DIR/.gitconfig" "install links .gitconfig"
  assert_is_symlink_to "$tmp_home/.copilot" "$REPO_DIR/.copilot" "install links .copilot"
  assert_is_symlink_to "$tmp_home/Library/Application Support/Code/User/settings.json" "$REPO_DIR/vscode/settings.json" "install links vscode settings"

  rm -rf "$tmp_home"
}

run_test_conflict_skip_keeps_existing_file() {
  local tmp_home existing_content
  tmp_home="$(mktemp -d)"
  existing_content="do-not-replace"
  printf '%s\n' "$existing_content" > "$tmp_home/.zshrc"

  printf 's\n' | HOME="$tmp_home" bash "$INSTALL_SCRIPT" --install >/dev/null

  if [[ -L "$tmp_home/.zshrc" ]]; then
    echo "  expected existing file to remain regular file"
    fail "conflict skip keeps existing"
  elif [[ "$(cat "$tmp_home/.zshrc")" == "$existing_content" ]]; then
    pass "conflict skip keeps existing"
  else
    echo "  existing file content changed"
    fail "conflict skip keeps existing"
  fi

  rm -rf "$tmp_home"
}

run_test_conflict_repo_backs_up_existing_file() {
  local tmp_home tmp_repo tmp_script existing_content backup_path
  tmp_home="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  tmp_script="$tmp_repo/install.sh"
  existing_content="backup-me"

  cp "$INSTALL_SCRIPT" "$tmp_script"
  copy_item_if_present "$REPO_DIR/.zshrc" "$tmp_repo/.zshrc"
  copy_item_if_present "$REPO_DIR/.vimrc" "$tmp_repo/.vimrc"
  copy_item_if_present "$REPO_DIR/.gitconfig" "$tmp_repo/.gitconfig"
  copy_item_if_present "$REPO_DIR/.copilot" "$tmp_repo/.copilot"
  mkdir -p "$tmp_repo/vscode"
  cp "$REPO_DIR/vscode/settings.json" "$tmp_repo/vscode/settings.json"
  cp "$REPO_DIR/vscode/extensions.txt" "$tmp_repo/vscode/extensions.txt"

  printf '%s\n' "$existing_content" > "$tmp_home/.zshrc"

  printf 'r\n' | HOME="$tmp_home" bash "$tmp_script" --install >/dev/null

  assert_is_symlink_to "$tmp_home/.zshrc" "$tmp_repo/.zshrc" "conflict repo replaces with symlink"

  backup_path="$tmp_repo/configs.backup$tmp_home/.zshrc"
  if [[ -f "$backup_path" ]] && [[ "$(cat "$backup_path")" == "$existing_content" ]]; then
    pass "conflict repo backs up original file"
  else
    echo "  expected backup file with original content at: $backup_path"
    fail "conflict repo backs up original file"
  fi

  rm -rf "$tmp_repo"
  rm -rf "$tmp_home"
}

run_test_update_uses_git_pull() {
  local tmp_bin log_file out
  tmp_bin="$(mktemp -d)"
  log_file="$(mktemp)"

  cat > "$tmp_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_GIT_LOG"
exit 0
EOF
  chmod +x "$tmp_bin/git"

  out="$(PATH="$tmp_bin:$PATH" MOCK_GIT_LOG="$log_file" bash "$INSTALL_SCRIPT" --update)"

  assert_contains "$out" "Pulling latest changes" "update announces pull"
  assert_contains "$(cat "$log_file")" "-C $REPO_DIR pull" "update runs git -C <repo> pull"

  rm -rf "$tmp_bin"
  rm -f "$log_file"
}

run_test_extensions_fails_when_cli_missing() {
  local out exit_code tmp_home tmp_repo tmp_script
  tmp_home="$(mktemp -d)"
  tmp_repo="$(mktemp -d)"
  tmp_script="$tmp_repo/install.sh"

  mkdir -p "$tmp_repo/vscode"
  cp "$INSTALL_SCRIPT" "$tmp_script"
  cp "$REPO_DIR/vscode/extensions.txt" "$tmp_repo/vscode/extensions.txt"
  # Force a missing CLI path so this test is stable across environments.
  sed -i.bak 's|^VSCODE_CLI=.*$|VSCODE_CLI="/nonexistent/vscode-cli"|' "$tmp_script"
  rm -f "$tmp_script.bak"

  set +e
  out="$(HOME="$tmp_home" bash "$tmp_script" --install-vscode-extensions 2>&1)"
  exit_code=$?
  set -e

  if [[ $exit_code -ne 0 ]]; then
    pass "extensions command fails when VS Code CLI path is unavailable"
  else
    echo "  expected non-zero exit code"
    fail "extensions command fails when VS Code CLI path is unavailable"
  fi

  assert_contains "$out" "VS Code CLI not found or not executable" "extensions failure explains missing CLI"

  rm -rf "$tmp_repo"
  rm -rf "$tmp_home"
}

main() {
  echo "Running install.sh tests..."

  run_test_help_output
  run_test_dryrun_table
  run_test_install_creates_symlinks
  run_test_conflict_skip_keeps_existing_file
  run_test_conflict_repo_backs_up_existing_file
  run_test_update_uses_git_pull
  run_test_extensions_fails_when_cli_missing

  echo ""
  echo "Passed: $PASS_COUNT"
  echo "Failed: $FAIL_COUNT"

  if [[ $FAIL_COUNT -ne 0 ]]; then
    exit 1
  fi
}

main "$@"
