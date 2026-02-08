/**
 * Rejected Soft Screen
 * 
 * Responsibilities:
 * - Acknowledge rejection
 * - Emit retry event
 */

import { MachineEvent } from '../../core/stateMachine';

export class RejectedSoftScreen {
    render() {
        console.log('\n--- [SCREEN] Rejected (Soft) ---');
        console.log('  "Okay, finding something else..."');
        console.log('  (Auto-retrying in 1s)');
        console.log('--------------------------------');
    }

    onRetry(): MachineEvent {
        console.log('  (System: Retrying)');
        return 'retry';
    }
}
