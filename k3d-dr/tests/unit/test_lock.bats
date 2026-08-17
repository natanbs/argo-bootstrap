#!/usr/bin/env bats
# test_lock.bats - Unit tests for lock.sh

load '../test_helper'

@test "lock_acquire creates lock file" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    run lock_acquire "backup"
    assert_success
    [[ -f "$LOCK_DIR/backup.lock" ]]
}

@test "lock_acquire fails when lock is held" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    mkdir -p "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/backup.lock"
    run lock_acquire "backup"
    assert_failure
}

@test "lock_release removes lock file" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    mkdir -p "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/backup.lock"
    run lock_release "backup"
    assert_success
    [[ ! -f "$LOCK_DIR/backup.lock" ]]
}

@test "lock_is_held returns true when lock exists" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    mkdir -p "$LOCK_DIR"
    echo "$$" > "$LOCK_DIR/backup.lock"
    run lock_is_held "backup"
    assert_success
}

@test "lock_is_held returns false when no lock" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    mkdir -p "$LOCK_DIR"
    run lock_is_held "backup"
    assert_failure
}

@test "lock_get_holder returns PID" {
    export LOCK_DIR="$TEST_TMPDIR/locks"
    mkdir -p "$LOCK_DIR"
    echo "12345" > "$LOCK_DIR/backup.lock"
    run lock_get_holder "backup"
    assert_success
    assert_equal "12345" "$output"
}