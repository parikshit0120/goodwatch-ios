/**
 * Calibration Screen
 * 
 * Responsibilities:
 * - Display pure UI (logs)
 * - Emit events on interaction
 */

import { MachineEvent, MachineContext } from '../../core/stateMachine';

export class CalibrationScreen {
    /**
     * Renders the screen to the "UI" (Console)
     */
    render() {
        console.log('\n--- [SCREEN] Calibration ---');
        console.log('  [CTA] Finish Calibration');
        console.log('----------------------------');
    }

    /**
     * Simulates a user completing calibration.
     * @returns Tuple of [Event, Payload]
     */
    onComplete(): { event: MachineEvent; payload: Partial<MachineContext> } {
        console.log('  (User Tapped: Finish Calibration)');
        return {
            event: 'calibration_done',
            payload: { valid_inputs: true }
        };
    }
}
