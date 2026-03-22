import Foundation

/// Sends transactional emails via ZeptoMail (Zoho) REST API.
/// Used for: welcome emails, password reset, subscription confirmation, account deletion confirmation.
///
/// The ZeptoMail API key is stored in the Supabase proxy worker to avoid embedding it client-side.
/// All email requests are routed through the proxy at /api/email.
final class GWEmailService {
    static let shared = GWEmailService()

    private let proxyBaseURL = "https://goodwatch.movie"

    private init() {}

    // MARK: - Email Types

    enum EmailType: String {
        case welcome = "welcome"
        case passwordReset = "password_reset"
        case subscriptionConfirmation = "subscription_confirmation"
        case deletionConfirmation = "deletion_confirmation"
    }

    // MARK: - Public API

    /// Send a welcome email after account creation.
    func sendWelcome(to email: String, name: String?) {
        send(type: .welcome, to: email, data: [
            "name": name ?? "there"
        ])
    }

    /// Send a subscription confirmation after Pro purchase.
    func sendSubscriptionConfirmation(to email: String, productId: String) {
        send(type: .subscriptionConfirmation, to: email, data: [
            "product_id": productId
        ])
    }

    /// Send a deletion confirmation after account deletion.
    func sendDeletionConfirmation(to email: String) {
        send(type: .deletionConfirmation, to: email, data: [:])
    }

    // MARK: - Private

    /// Fire-and-forget email send via proxy worker.
    private func send(type: EmailType, to email: String, data: [String: String]) {
        guard let url = URL(string: "\(proxyBaseURL)/api/email") else {
            #if DEBUG
            print("[GWEmail] Invalid proxy URL")
            #endif
            return
        }

        var payload: [String: Any] = [
            "type": type.rawValue,
            "to": email
        ]
        if !data.isEmpty {
            payload["data"] = data
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            #if DEBUG
            print("[GWEmail] Serialization failed: \(error.localizedDescription)")
            #endif
            return
        }

        GWNetworkSession.shared.dataTask(with: request) { _, response, error in
            #if DEBUG
            if let error = error {
                print("[GWEmail] Send failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse {
                print("[GWEmail] \(type.rawValue) email sent: HTTP \(http.statusCode)")
            }
            #endif
        }.resume()
    }
}
