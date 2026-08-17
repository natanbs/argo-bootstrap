#!/usr/bin/env bats
# test_config.bats - Unit tests for config.sh

load '../test_helper'

@test "config_load reads valid configuration" {
    local config_file
    config_file="$(create_test_config)"
    
    run config_load "$config_file"
    assert_success
}

@test "config_load fails for missing file" {
    run config_load "/nonexistent/config.yml"
    assert_failure
}

@test "config_get returns repository count" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get "repositories.count"
    assert_success
    assert_equal "1" "$output"
}

@test "config_get returns kopia repository path" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get "kopia.repository_path"
    assert_success
    assert_equal "/tmp/kopia-repo" "$output"
}

@test "config_get returns port offset" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get "port_offset"
    assert_success
    assert_equal "0" "$output"
}

@test "config_get returns dns suffix" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get "dns_suffix"
    assert_success
    assert_equal "lab=bak" "$output"
}

@test "config_get_repository returns name" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get_repository 0 "name"
    assert_success
    assert_equal "test-repo" "$output"
}

@test "config_get_repository returns path" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get_repository 0 "path"
    assert_success
    assert_equal "/tmp/test-repo" "$output"
}

@test "config_get_repository returns pvc" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get_repository 0 "pvc"
    assert_success
    assert_equal "test-pvc" "$output"
}

@test "config_get_repository returns namespace" {
    local config_file
    config_file="$(create_test_config)"
    config_load "$config_file"
    
    run config_get_repository 0 "namespace"
    assert_success
    assert_equal "default" "$output"
}

@test "config_validate passes for valid config" {
    local config_file
    config_file="$(create_test_config)"
    
    run config_validate
    assert_success
}