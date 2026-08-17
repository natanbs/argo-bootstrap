#!/usr/bin/env bats
# test_errors.bats - Unit tests for errors.sh

load '../test_helper'

@test "error_create returns valid JSON" {
    run error_create "E001" "Test error" "test" "Test remediation"
    assert_success
    assert_contains "$output" "error_code"
    assert_contains "$output" "E001"
    assert_contains "$output" "message"
    assert_contains "$output" "Test error"
    assert_contains "$output" "component"
    assert_contains "$output" "test"
    assert_contains "$output" "suggested_remediation"
    assert_contains "$output" "Test remediation"
}

@test "error_create handles empty remediation" {
    run error_create "E001" "Test error" "test"
    assert_success
    assert_contains "$output" "error_code"
    assert_contains "$output" "E001"
    ! assert_contains "$output" "suggested_remediation"
}

@test "error_report stores last error" {
    error_report "E001" "Test error" "test" "Test remediation"
    run error_get_last
    assert_success
    assert_contains "$output" "code=E001"
    assert_contains "$output" "message=Test error"
    assert_contains "$output" "component=test"
}

@test "error_clear resets last error" {
    error_report "E001" "Test error" "test"
    run error_clear
    assert_success
    run error_get_last
    assert_success
    assert_contains "$output" "code="
    assert_contains "$output" "message="
    assert_contains "$output" "component="
}

@test "error_is matches error code" {
    error_report "E001" "Test error" "test"
    run error_is "E001"
    assert_success
}

@test "error_is rejects non-matching code" {
    error_report "E001" "Test error" "test"
    run error_is "E002"
    assert_failure
}

@test "error_report_auto finds matching code" {
    run error_report_auto "test" "Configuration file not found"
    assert_success
    assert_contains "$output" "E001"
}