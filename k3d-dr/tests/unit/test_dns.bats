#!/usr/bin/env bats
# test_dns.bats - Unit tests for dns.sh

load '../test_helper'

@test "dns_init parses suffix correctly" {
    run dns_init "lab=bak"
    assert_success
    assert_equal "lab" "$(dns_get_original)"
    assert_equal "bak" "$(dns_get_replacement)"
}

@test "dns_init rejects invalid format" {
    run dns_init "invalid"
    assert_failure
}

@test "dns_init rejects empty parts" {
    run dns_init "=bak"
    assert_failure
}

@test "dns_rewrite replaces suffix" {
    dns_init "lab=bak"
    run dns_rewrite "http://analyst.lab"
    assert_success
    assert_equal "http://analyst.bak" "$output"
}

@test "dns_rewrite passes through when not configured" {
    run dns_rewrite "http://analyst.lab"
    assert_success
    assert_equal "http://analyst.lab" "$output"
}

@test "dns_is_configured returns true when set" {
    dns_init "lab=bak"
    run dns_is_configured
    assert_success
}

@test "dns_is_configured returns false when not set" {
    run dns_is_configured
    assert_failure
}

@test "dns_reset clears configuration" {
    dns_init "lab=bak"
    run dns_reset
    assert_success
    run dns_is_configured
    assert_failure
}