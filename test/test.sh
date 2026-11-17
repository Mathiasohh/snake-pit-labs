#!/usr/bin/env bash
# Tester nvim-installationen fra .devcontainer/debian/Dockerfile.debian lokalt.
# Brug: ./test/test.sh            (arkitektur findes automatisk)
#       TARGETARCH=arm64 ./test/test.sh
set -euo pipefail

NVIM_VERSION="${NVIM_VERSION:-0.12.6}"

# BuildKit sætter TARGETARCH (amd64/arm64). Lokalt udleder vi det selv.
if [ -z "${TARGETARCH:-}" ]; then
    case "$(uname -m)" in
        x86_64) TARGETARCH=amd64 ;;
        aarch64 | arm64) TARGETARCH=arm64 ;;
        *) echo "Ukendt arkitektur: $(uname -m)" >&2; exit 1 ;;
    esac
fi
echo "TARGETARCH=${TARGETARCH}"

# Samme logik som i Dockerfile: alt herunder skal holdes i sync med den.
USER_BIN="$(mktemp -d)"
trap 'rm -rf "$USER_BIN"' EXIT

NVIM_ARCH="$([ "$TARGETARCH" = amd64 ] && echo x86_64 || echo "$TARGETARCH")" \
    && curl -fsSL "https://github.com/neovim/neovim/releases/download/v${NVIM_VERSION}/nvim-linux-${NVIM_ARCH}.tar.gz" \
    | tar -xz -C "$USER_BIN" --strip-components=1

# Verificér resultatet
"$USER_BIN/bin/nvim" --version | head -n 1
echo "OK: nvim ${NVIM_VERSION} (${NVIM_ARCH}) installeret i ${USER_BIN}"
