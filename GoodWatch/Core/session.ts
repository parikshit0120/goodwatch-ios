/**
 * Session Definition
 */

export interface Session {
    id: string;
    startTime: number;
    // Context snapshot
    userPlatforms: string[];
    userLanguages: string[];
}

/**
 * Helper to create a new session
 */
export function createSession(userPlatforms: string[] = [], userLanguages: string[] = ['en']): Session {
    return {
        id: `sess_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        startTime: Date.now(),
        userPlatforms,
        userLanguages
    };
}
