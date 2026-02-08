/**
 * Show Pick Screen
 * 
 * Responsibilities:
 * - Display pure UI (logs) - One placeholder card
 * - Emit events: watch_now, seen_this, not_feeling_it
 */

import { MachineEvent } from '../../core/stateMachine';
import { Movie } from '../../core/selector';

export class ShowPickScreen {
    private currentMovie: Movie | null = null;

    /**
     * Renders the screen to the "UI" (Console)
     */
    render(movie: Movie) {
        this.currentMovie = movie;
        console.log('\n--- [SCREEN] Show Pick ---');
        console.log(`  [CARD] "${movie.title}" (ID: ${movie.id})`);
        console.log('  [Actions] [W]atch Now | [S]een This | [N]ot Feeling It');
        console.log('--------------------------');
    }

    /**
     * Simulates user actions
     */
    onWatchNow(): MachineEvent {
        console.log(`  (User Tapped: Watch Now for ID: ${this.currentMovie?.id})`);
        return 'watch_now';
    }

    onSeenThis(): MachineEvent {
        console.log(`  (User Tapped: Seen This for ID: ${this.currentMovie?.id})`);
        return 'seen_this';
    }

    onNotFeelingIt(): MachineEvent {
        console.log(`  (User Tapped: Not Feeling It for ID: ${this.currentMovie?.id})`);
        return 'not_feeling_it';
    }
}
