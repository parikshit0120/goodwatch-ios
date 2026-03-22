import Foundation

// Quick script to inspect database structure
let url = "https://jdjqrlkynwfhbtyuddjk.supabase.co/rest/v1/movies?select=title,genres,ott_providers,original_language,year,composite_score&limit=5"
let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpkanFybGt5bndmaGJ0eXVkZGprIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ0NzUwMTEsImV4cCI6MjA4MDA1MTAxMX0.KDRMLCewVMp3lwphkUvtoWOkg6kyAk8iSbVkRKiHYSk"

var request = URLRequest(url: URL(string: url)!)
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue(anonKey, forHTTPHeaderField: "apikey")
request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    if let data = data, let str = String(data: data, encoding: .utf8) {
        print(str)
    }
    exit(0)
}
task.resume()
RunLoop.main.run()
