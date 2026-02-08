/**
 * Decision Ready Screen
 * 
 * Responsibilities:
 * - Display pure UI (logs)
 * - Auto-trigger event (System Action)
 */

import { MachineEvent } from '../../core/stateMachine';

export class DecisionReadyScreen {
    /**
     * Renders the placeholder
     */
    render() {
        console.log('\n--- [SCREEN] Decision Ready ---');
        console.log('  (System is preparing recommendation...)');
        console.log('-------------------------------');
    }

    /**
     * Returns the auto-trigger event
     */
    onAuto(): MachineEvent {
        console.log('  (Auto-triggering decision request)');
        return 'decision_requested';
    }
}
