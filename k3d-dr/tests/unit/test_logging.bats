#!/usr/bin/env bats
# test_logging.bats - Unit tests for logging.sh

load '../test_helper'

@test "log_info returns valid JSON" {
    run log_info "Test message" "test"
    assert_success
    assert_contains "$output" "timestamp"
    assert_contains "$output" "level"
    assert_contains "$output" "info"
    assert_contains "$output" "message"
    assert_contains "$output" "Test message"
    assert_contains "$output" "component"
    assert_contains "$output" "test"
}

@test "log_error returns valid JSON" {
    run log_error "Error message" "test"
    assert_success
    assert_contains "$output" "level"
    assert_contains "$output" "error"
    assert_contains "$output" "Error message"
}

@test "set_log_level changes level" {
    set_log_level "debug"
    assert_equal "debug" "$LOG_LEVEL"
}

@test "set_log_file creates log directory" {
    local test_dir="$TEST_TMPDIR/logs"
    set_log_file "$test_dir/test.log"
    assert_equal "$test_dir/test.log" "$LOG_FILE"
}

@test "init_logging sets defaults" {
    unset LOG_LEVEL
    unset LOG_FILE
    run init_logging
    assert_success
    assert_equal "info" "$LOG_LEVEL"
}