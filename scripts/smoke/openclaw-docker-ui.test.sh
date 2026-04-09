#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/scripts/smoke/openclaw-docker-ui.sh"

fail() {
  echo "[openclaw-docker-ui.test] ERROR: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected output to contain: $needle"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected output to omit: $needle"
}

write_stub_toolchain() {
  local bin_dir="$1"

  cat >"$bin_dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "clone" ]]; then
  target="${@: -1}"
  mkdir -p "$target/.git"
  exit 0
fi

if [[ "$1" == "-C" ]]; then
  repo_dir="$2"
  shift 2
  case "$1" in
    fetch|checkout)
      exit 0
      ;;
    rev-parse)
      if [[ "${*: -1}" == "--short" ]]; then
        printf 'abc123\n'
      fi
      exit 0
      ;;
  esac
fi

exit 0
EOF
  chmod +x "$bin_dir/git"

  cat >"$bin_dir/docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

load_env_file() {
  local env_file="$1"
  if [[ -n "$env_file" && -f "$env_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
  fi
}

if [[ "$1" == "build" ]]; then
  exit 0
fi

if [[ "$1" == "network" && "$2" == "inspect" ]]; then
  printf '172.18.0.1\n'
  exit 0
fi

if [[ "$1" == "compose" ]]; then
  shift
  env_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --env-file)
        env_file="$2"
        shift 2
        ;;
      -f)
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  load_env_file "$env_file"

  case "$1" in
    down|up|logs)
      exit 0
      ;;
    exec)
      exit 0
      ;;
    run)
      printf 'http://127.0.0.1:%s/#token=%s\n' "${OPENCLAW_GATEWAY_PORT:-18789}" "${OPENCLAW_GATEWAY_TOKEN:-missing-token}"
      exit 0
      ;;
  esac
fi

exit 0
EOF
  chmod +x "$bin_dir/docker"

  cat >"$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '200'
EOF
  chmod +x "$bin_dir/curl"

  cat >"$bin_dir/openssl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'generated-token-for-test\n'
EOF
  chmod +x "$bin_dir/openssl"
}

permission_mode() {
  stat -f "%Lp" "$1"
}

run_case() {
  local print_live="$1"
  local base_dir
  base_dir="$(mktemp -d "${TMPDIR:-/tmp}/openclaw-docker-ui-test.XXXXXX")"
  trap 'rm -rf "$base_dir"' RETURN

  local bin_dir="$base_dir/bin"
  local home_dir="$base_dir/home"
  local docker_dir="$base_dir/openclaw-docker"
  local config_dir="$base_dir/config"
  mkdir -p "$bin_dir" "$home_dir"
  write_stub_toolchain "$bin_dir"

  local output
  output="$(
    HOME="$home_dir" \
    PATH="$bin_dir:/usr/bin:/bin:/usr/sbin:/sbin" \
    OPENAI_API_KEY="sk-test-openai-key" \
    OPENCLAW_DOCKER_DIR="$docker_dir" \
    OPENCLAW_CONFIG_DIR="$config_dir" \
    OPENCLAW_GATEWAY_TOKEN="local-test-token-1234567890" \
    OPENCLAW_BUILD="0" \
    OPENCLAW_WAIT_SECONDS="1" \
    OPENCLAW_PRINT_LIVE_DASHBOARD_URL="$print_live" \
    bash "$SCRIPT_PATH" 2>&1
  )"

  [[ -f "$config_dir/openclaw.compose.env" ]] || fail "compose env file was not created"
  [[ "$(permission_mode "$config_dir/openclaw.compose.env")" == "600" ]] || fail "compose env file mode is not 600"
  [[ ! -e "$docker_dir/.env" ]] || fail "legacy docker clone .env should not exist"
  assert_contains "$output" "--env-file \"$config_dir/openclaw.compose.env\""

  if [[ "$print_live" == "1" ]]; then
    assert_contains "$output" "http://127.0.0.1:18789/#token=local-test-token-1234567890"
  else
    assert_contains "$output" "http://127.0.0.1:18789/#token=<redacted>"
    assert_contains "$output" "Live token output is suppressed by default"
    assert_not_contains "$output" "#token=local-test-token-1234567890"
  fi

  rm -rf "$base_dir"
  trap - RETURN
}

run_case 0
run_case 1

echo "[openclaw-docker-ui.test] ok"
