/**
 * GoodWatch Core System - State Machine
 * Based on docs/GoodWatch_Core_System_v1.md
 */

// 3. Core Flow — State Machine (Formal Table)
export enum StateId {
    S0_IDLE = 'S0',
    S1_ENTRY = 'S1',
    S2_CALIBRATION = 'S2',
    S3_DECISION_READY = 'S3',
    S4_SHOW_PICK = 'S4',
    S5_ACCEPTED = 'S5',
    S6_REJECTED_SOFT = 'S6',
    S7_REJECTED_HARD = 'S7',
    S8_SEEN_FLAGGED = 'S8',
    S9_EXIT = 'S9',
}

// 4. State Transitions & Rules - Events
export type MachineEvent =
    | 'app_open'
    | 'first_time_user'
    | 'returning_user'
    | 'calibration_done'
    | 'decision_requested'
    | 'watch_now'
    | 'seen_this'
    | 'not_feeling_it'
    | 'retry' // Used for both soft reject retry and hard reject retry scenarios described in doc
    | 'replace' // S8 -> S4
    | 'reset_context' // S7 -> S2
    | 'exit_app'; // S5 -> S9

// Context for rules
export interface MachineContext {
    reject_count: number;
    valid_inputs: boolean; // For calibration_done condition
}

const INITIAL_CONTEXT: MachineContext = {
    reject_count: 0,
    valid_inputs: false,
};

export class GoodWatchStateMachine {
    private _currentState: StateId;
    private _context: MachineContext;

    constructor() {
        this._currentState = StateId.S0_IDLE;
        this._context = { ...INITIAL_CONTEXT };
    }

    get state(): StateId {
        return this._currentState;
    }

    get context(): Readonly<MachineContext> {
        return this._context;
    }

    /**
     * Executes a transition based on the provided event.
     * strictly follows "Allowed Transitions Only" table.
     */
    transition(event: MachineEvent, payload?: Partial<MachineContext>): StateId {
        const from = this._currentState;

        // Update context with payload if provided (e.g. setting valid_inputs)
        if (payload) {
            this._context = { ...this._context, ...payload };
        }

        switch (from) {
            case StateId.S0_IDLE:
                if (event === 'app_open') {
                    // Side Effect: init_session (reset context)
                    this._context = { ...INITIAL_CONTEXT };
                    this._currentState = StateId.S1_ENTRY;
                    return this._currentState;
                }
                break;

            case StateId.S1_ENTRY:
                if (event === 'first_time_user') {
                    // Side Effect: load_calibration
                    this._currentState = StateId.S2_CALIBRATION;
                    return this._currentState;
                }
                if (event === 'returning_user') {
                    // Side Effect: load_user_context
                    this._currentState = StateId.S3_DECISION_READY;
                    return this._currentState;
                }
                break;

            case StateId.S2_CALIBRATION:
                if (event === 'calibration_done') {
                    // Condition: valid_inputs
                    if (this.context.valid_inputs) {
                        // Side Effect: save_context
                        this._currentState = StateId.S3_DECISION_READY;
                        return this._currentState;
                    }
                }
                break;

            case StateId.S3_DECISION_READY:
                if (event === 'decision_requested') {
                    // Side Effect: select_movie
                    this._currentState = StateId.S4_SHOW_PICK;
                    return this._currentState;
                }
                break;

            case StateId.S4_SHOW_PICK:
                if (event === 'watch_now') {
                    // Side Effect: log_accept
                    this._currentState = StateId.S5_ACCEPTED;
                    return this._currentState;
                }
                if (event === 'seen_this') {
                    // Side Effect: mark_seen
                    this._currentState = StateId.S8_SEEN_FLAGGED;
                    return this._currentState;
                }
                if (event === 'not_feeling_it') {
                    if (this._context.reject_count >= 3) {
                        this._currentState = StateId.S7_REJECTED_HARD;
                        return this._currentState;
                    }
                    // Condition: reject_count < 3
                    if (this._context.reject_count < 3) {
                        // Side Effect: increment_reject
                        this._context.reject_count++;
                        this._currentState = StateId.S6_REJECTED_SOFT;
                        return this._currentState;
                    }
                }
                break;

            case StateId.S5_ACCEPTED:
                if (event === 'exit_app') {
                    // Side Effect: end_session
                    this._currentState = StateId.S9_EXIT;
                    return this._currentState;
                }
                break;

            case StateId.S6_REJECTED_SOFT:
                if (event === 'retry') {
                    if (this._context.reject_count < 3) {
                        // Side Effect: lower_risk
                        // Transition: S6 -> S4
                        this._currentState = StateId.S4_SHOW_PICK;
                        return this._currentState;
                    } else {
                        // Condition: reject_count >= 3
                        // Side Effect: lock_session
                        // Transition: S6 -> S7
                        this._currentState = StateId.S7_REJECTED_HARD;
                        return this._currentState;
                    }
                }
                break;

            case StateId.S7_REJECTED_HARD:
                if (event === 'reset_context') {
                    // Side Effect: reset_risk
                    // S7 -> S2
                    this._currentState = StateId.S2_CALIBRATION;
                    return this._currentState;
                }
                break;

            case StateId.S8_SEEN_FLAGGED:
                if (event === 'replace') {
                    // Side Effect: select_next_movie
                    this._currentState = StateId.S4_SHOW_PICK;
                    return this._currentState;
                }
                break;

            case StateId.S9_EXIT:
                // Terminal state
                break;
        }

        // If no transition found
        throw new Error(`Illegal transition from ${from} with event ${event}`);
    }
}
