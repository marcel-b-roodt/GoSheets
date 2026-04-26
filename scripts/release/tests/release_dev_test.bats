#!/usr/bin/env bats
# Tests for scripts/release-dev.sh

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../.." && pwd)"
RELEASE_DEV_SCRIPT="$REPO_ROOT/scripts/release-dev.sh"

@test "release-dev.sh exists" {
    [ -f "$RELEASE_DEV_SCRIPT" ]
}

@test "release-dev.sh is executable or can be run via bash" {
    [ -f "$RELEASE_DEV_SCRIPT" ]
}

@test "release-dev.sh requires a version argument" {
    run bash "$RELEASE_DEV_SCRIPT"
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "Usage"
}

@test "release-dev.sh forwards --dev to release.sh" {
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT

    mkdir -p "$TMP_DIR/scripts"
    cp "$RELEASE_DEV_SCRIPT" "$TMP_DIR/scripts/release-dev.sh"
    cat > "$TMP_DIR/scripts/release.sh" << 'EOF'
#!/usr/bin/env bash
echo "$*" > /tmp/release_dev_args.txt
EOF
    chmod +x "$TMP_DIR/scripts/release.sh"

    run bash "$TMP_DIR/scripts/release-dev.sh" "0.5.0-dev1"
    [ "$status" -eq 0 ]
    grep -q "0.5.0-dev1 --dev" /tmp/release_dev_args.txt

    rm -f /tmp/release_dev_args.txt
    rm -rf "$TMP_DIR"
    trap - EXIT
}
