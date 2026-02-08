/**
 * Rejected Hard Screen
 * 
 * Responsibilities:
 * - Show limit reached message
 * - Emit reset_context event
 */

import { MachineEvent } from '../../core/stateMachine';

export class RejectedHardScreen {
    render() {
        console.log('\n--- [SCREEN] Rejected (Hard) ---');
        console.log('  "You seem undecided. Let\'s start over."');
        console.log('  [CTA] Start Over');
        console.log('--------------------------------');
    }

    onReset(): MachineEvent {
        console.log('  (User Tapped: Start Over)');
        return 'reset_context';
    }
}
