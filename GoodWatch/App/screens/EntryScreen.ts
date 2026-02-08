/**
 * Entry Screen
 * 
 * Responsibilities:
 * - Display pure UI (logs)
 * - Emit events on interaction
 * - No access to state machine or context
 */

import { MachineEvent } from '../../core/stateMachine';

export class EntryScreen {
    /**
     * Renders the screen to the "UI" (Console)
     */
    render() {
        console.log('\n--- [SCREEN] Entry ---');
        console.log('  Welcome to GoodWatch.');
        console.log('  [CTA] Tap to start');
        console.log('----------------------');
    }

    /**
     * Simulates a user tap action.
     * @returns The event to emit to the system.
     */
    onTap(isReturningUser: boolean = false): MachineEvent {
        // Logic to determine event based on "UI state" or arguments
        // In a real app, this might check props or local state.
        // For v1 requirements: emit first_time_user or returning_user
        if (isReturningUser) {
            console.log('  (User Tapped: Returning User)');
            return 'returning_user';
        } else {
            console.log('  (User Tapped: First Time User)');
            return 'first_time_user';
        }
    }
}
