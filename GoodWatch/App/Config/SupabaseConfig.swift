import Foundation

enum SupabaseConfig {
    // Proxied through Cloudflare Worker to bypass ISP-level DNS blocks
    // in India. The worker forwards to jdjqrlkynwfhbtyuddjk.supabase.co
    // Direct URL kept as fallback: jdjqrlkynwfhbtyuddjk.supabase.co
    static let url = "https://api.goodwatch.movie"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkanFybGt5bndmaGJ0eXVkZGprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0NzUwMTEsImV4cCI6MjA4MDA1MTAxMX0.KDRMLCewVMp3lwphkUvtoWOkg6kyAk8iSbVkRKiHYSk"

    static var isConfigured: Bool {
        !url.isEmpty && !anonKey.isEmpty
    }
}
