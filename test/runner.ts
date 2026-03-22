/**
 * Automated Test Runner
 * verifying core/stateMachine.ts using node:assert
 */

import { strict as assert } from 'node:assert';
import { GoodWatchStateMachine, StateId } from '../core/stateMachine';

console.log('🧪 Starting Automated Core Tests...');

async function testHappyPath() {
    console.log('   Test: Happy Path');
    const machine = new GoodWatchStateMachine();
    
    assert.equal(machine.state, StateId.S0_IDLE, 'Should start in IDLE');
    
    machine.transition('app_open');
    assert.equal(machine.state, StateId.S1_ENTRY, 'Should move to ENTRY');
    
    machine.transition('first_time_user');
    assert.equal(machine.state, StateId.S2_CALIBRATION, 'Should move to CALIBRATION');
    
    machine.transition('calibration_done', { valid_inputs: true });
    assert.equal(machine.state, StateId.S3_DECISION_READY, 'Should move to DECISION_READY');
    
    machine.transition('decision_requested');
    assert.equal(machine.state, StateId.S4_SHOW_PICK, 'Should move to SHOW_PICK');
    
    machine.transition('watch_now');
    assert.equal(machine.state, StateId.S5_ACCEPTED, 'Should move to ACCEPTED');
    
    machine.transition('exit_app');
    assert.equal(machine.state, StateId.S9_EXIT, 'Should move to EXIT');
    
    console.log('   ✅ Happy Path Passed');
}

async function testRejectionLimit() {
    console.log('   Test: Rejection Limit (Hard Stop)');
    const machine = new GoodWatchStateMachine();
    
    // Fast forward to SHOW_PICK
    machine.transition('app_open');
    machine.transition('returning_user');
    machine.transition('decision_requested');
    assert.equal(machine.state, StateId.S4_SHOW_PICK);
    
    // Reject 1
    machine.transition('not_feeling_it');
    assert.equal(machine.state, StateId.S6_REJECTED_SOFT, 'Should be Soft Reject 1');
    assert.equal(machine.context.reject_count, 1);
    
    machine.transition('retry');
    assert.equal(machine.state, StateId.S4_SHOW_PICK);
    
    // Reject 2
    machine.transition('not_feeling_it');
    assert.equal(machine.state, StateId.S6_REJECTED_SOFT, 'Should be Soft Reject 2');
    assert.equal(machine.context.reject_count, 2);
    
    machine.transition('retry');
    assert.equal(machine.state, StateId.S4_SHOW_PICK);
    
    // Reject 3
    machine.transition('not_feeling_it');
    assert.equal(machine.state, StateId.S6_REJECTED_SOFT, 'Should be Soft Reject 3');
    assert.equal(machine.context.reject_count, 3);
    
    // Now Retry.
    // S6 -> retry:
    // if (count < 3) -> S4
    // else -> S7 (Hard Reject)
    machine.transition('retry');
    assert.equal(machine.state, StateId.S7_REJECTED_HARD, 'Should be Hard Reject (S7)');
    
    console.log('   ✅ Rejection Limit Test Passed');
}

async function runTests() {
    try {
        await testHappyPath();
        await testRejectionLimit();
        console.log('\n🎉 ALL TESTS PASSED. Core is stable.');
        process.exit(0);
    } catch (e) {
        console.error('\n❌ TEST FAILED');
        console.error(e);
        process.exit(1);
    }
}

runTests();
