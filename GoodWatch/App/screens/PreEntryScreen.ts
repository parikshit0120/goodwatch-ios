import { UIScreen } from '../../core/types';

/**
 * PreEntryScreen
 * A static onboarding screen outside the core state machine.
 */
export class PreEntryScreen {
    getUI(): UIScreen {
        return {
            title: "GoodWatch",
            body: [
                "---------",
                "Curated movies for tonight.",
                "No noise. Just good watches.",
                "---------"
            ],
            actions: [
                { label: "Show me tonight's pick", actionKey: "app_open", primary: true }
            ]
        };
    }

    // Interaction handler (simulated)
    onCta(): boolean {
        return true;
    }
}
