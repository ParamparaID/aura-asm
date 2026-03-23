#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
AURA_BIN="${ROOT_DIR}/aura-shell"
LOG_FILE="${ROOT_DIR}/build/nested-smoke.log"

DURATION_SEC=5
CLIENT_CMD=""
CI_MODE=0

usage() {
    cat <<'EOF'
Usage: tools/test_nested_smoke.sh [--duration SEC] [--client CMD] [--ci]

Smoke-test for nested Aura Shell run:
1) starts ./aura-shell inside host Wayland session
2) discovers compositor socket created by Aura
3) launches a Wayland terminal client on Aura display
4) keeps it running for N seconds and exits with pass/fail

Options:
  --duration SEC   Keep test running SEC seconds (default: 5)
  --client CMD     Client command to run (default auto-detect: foot -> weston-terminal)
  --ci             Graceful skip mode for CI/headless environments (exit 0 on missing prereqs)
  -h, --help       Show this message
EOF
}

pick_client() {
    if [[ -n "${CLIENT_CMD}" ]]; then
        echo "${CLIENT_CMD}"
        return 0
    fi
    if command -v foot >/dev/null 2>&1; then
        echo "foot"
        return 0
    fi
    if command -v weston-terminal >/dev/null 2>&1; then
        echo "weston-terminal"
        return 0
    fi
    return 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --duration)
                DURATION_SEC="${2:-}"
                shift 2
                ;;
            --client)
                CLIENT_CMD="${2:-}"
                shift 2
                ;;
            --ci)
                CI_MODE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown arg: $1" >&2
                usage
                exit 2
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    ci_skip() {
        local msg="$1"
        if [[ "${CI_MODE}" -eq 1 ]]; then
            echo "SKIP: ${msg}"
            exit 0
        fi
        echo "FAIL: ${msg}" >&2
        exit 1
    }

    if [[ ! -x "${AURA_BIN}" ]]; then
        ci_skip "aura-shell binary is missing. Run 'make aura-shell' first."
    fi

    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        ci_skip "WAYLAND_DISPLAY is not set. Run inside host Wayland session."
    fi

    local runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
    mkdir -p "${ROOT_DIR}/build"

    local host_display="${WAYLAND_DISPLAY}"
    local before_sockets after_sockets
    before_sockets="$(ls "${runtime_dir}"/wayland-* 2>/dev/null || true)"

    echo "Starting Aura Shell (nested on ${host_display})..."
    (
        cd "${ROOT_DIR}"
        ./aura-shell >"${LOG_FILE}" 2>&1
    ) &
    local aura_pid=$!
    local client_pid=0

    cleanup() {
        if [[ ${client_pid} -gt 0 ]]; then
            kill "${client_pid}" >/dev/null 2>&1 || true
            wait "${client_pid}" 2>/dev/null || true
        fi
        kill "${aura_pid}" >/dev/null 2>&1 || true
        wait "${aura_pid}" 2>/dev/null || true
    }
    trap cleanup EXIT

    local aura_display=""
    for _ in $(seq 1 30); do
        if ! kill -0 "${aura_pid}" >/dev/null 2>&1; then
            echo "FAIL: aura-shell exited early. See ${LOG_FILE}" >&2
            exit 1
        fi
        after_sockets="$(ls "${runtime_dir}"/wayland-* 2>/dev/null || true)"
        aura_display="$(comm -13 <(printf "%s\n" "${before_sockets}" | sed '/^$/d' | sort) <(printf "%s\n" "${after_sockets}" | sed '/^$/d' | sort) | xargs -r -n1 basename | head -n1 || true)"
        if [[ -n "${aura_display}" ]]; then
            break
        fi
        sleep 0.2
    done

    if [[ -z "${aura_display}" ]]; then
        ci_skip "could not discover Aura Wayland socket in ${runtime_dir}"
    fi

    local client
    if ! client="$(pick_client)"; then
        ci_skip "no Wayland terminal client found (tried foot/weston-terminal). Use --client <cmd>."
    fi

    echo "Aura display detected: ${aura_display}"
    echo "Launching client: ${client}"
    WAYLAND_DISPLAY="${aura_display}" ${client} >/dev/null 2>&1 &
    client_pid=$!

    sleep "${DURATION_SEC}"

    if ! kill -0 "${aura_pid}" >/dev/null 2>&1; then
        echo "FAIL: aura-shell terminated during smoke run. See ${LOG_FILE}" >&2
        exit 1
    fi
    if ! kill -0 "${client_pid}" >/dev/null 2>&1; then
        echo "FAIL: client exited during smoke run." >&2
        exit 1
    fi

    echo "PASS: nested smoke test succeeded (${DURATION_SEC}s)."
}

main "$@"
