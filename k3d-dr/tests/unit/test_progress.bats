#!/usr/bin/env bats
# test_progress.bats - Unit tests for progress.sh

load '../test_helper'

@test "progress_init sets initial state" {
    progress_init 100 "backup"
    assert_equal "100" "$PROGRESS_TOTAL"
    assert_equal "0" "$PROGRESS_CURRENT"
    assert_equal "backup" "$PROGRESS_OPERATION"
}

@test "progress_update changes current value" {
    progress_init 100 "backup"
    progress_update 50
    assert_equal "50" "$PROGRESS_CURRENT"
}

@test "progress_update changes phase" {
    progress_init 100 "backup"
    progress_update 50 "processing"
    assert_equal "50" "$PROGRESS_CURRENT"
    assert_equal "processing" "$PROGRESS_PHASE"
}

@test "progress_increment increases current by 1" {
    progress_init 100 "backup"
    progress_increment
    assert_equal "1" "$PROGRESS_CURRENT"
}

@test "progress_increment changes phase" {
    progress_init 100 "backup"
    progress_increment "phase1"
    assert_equal "1" "$PROGRESS_CURRENT"
    assert_equal "phase1" "$PROGRESS_PHASE"
}

@test "progress_complete sets current to total" {
    progress_init 100 "backup"
    progress_complete
    assert_equal "100" "$PROGRESS_CURRENT"
    assert_equal "Completed" "$PROGRESS_PHASE"
}