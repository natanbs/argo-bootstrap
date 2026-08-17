#!/usr/bin/env bats
# test_ports.bats - Unit tests for ports.sh

load '../test_helper'

@test "ports_init sets offset correctly" {
    run ports_init 100
    assert_success
    assert_equal "100" "$(ports_get_offset)"
}

@test "ports_init rejects negative offset" {
    run ports_init -1
    assert_failure
}

@test "ports_init rejects offset > 65000" {
    run ports_init 65001
    assert_failure
}

@test "ports_get_api_port applies offset" {
    ports_init 100
    run ports_get_api_port
    assert_success
    assert_equal "6543" "$output"
}

@test "ports_get_nodeport applies offset" {
    ports_init 100
    run ports_get_nodeport 30000
    assert_success
    assert_equal "30100" "$output"
}

@test "ports_get_nodeport_range returns correct range" {
    ports_init 100
    run ports_get_nodeport_range
    assert_success
    assert_equal "30100-32867" "$output"
}

@test "ports_reset sets offset to 0" {
    ports_init 100
    run ports_reset
    assert_success
    assert_equal "0" "$(ports_get_offset)"
}