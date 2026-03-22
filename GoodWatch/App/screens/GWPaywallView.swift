import SwiftUI
import RevenueCatUI
import PostHog

/// Paywall sheet triggered by the GWShowPaywall notification.
/// Presents RevenueCatUI's PaywallView for the "GoodWatch Movies Pro" offering
/// with a dismiss button and automatic subscription status refresh on purchase.
struct GWPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PaywallView()
                .onPurchaseCompleted { customerInfo in
                    PostHogSDK.shared.capture("paywall_converted")
                    Task {
                        await GWSubscriptionManager.shared.refreshStatus()
                    }
                    dismiss()
                }
                .onRestoreCompleted { _ in
                    PostHogSDK.shared.capture("paywall_converted")
                    Task {
                        await GWSubscriptionManager.shared.refreshStatus()
                    }
                    dismiss()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Maybe later") {
                            PostHogSDK.shared.capture("paywall_dismissed")
                            dismiss()
                        }
                    }
                }
        }
        .onAppear {
            PostHogSDK.shared.capture("paywall_shown")
        }
    }
}

/// View modifier that listens for the GWShowPaywall notification
/// and presents the paywall sheet. Attach this to the root view.
struct GWPaywallModifier: ViewModifier {
    @State private var showPaywall = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .gwShowPaywall)) { _ in
                showPaywall = true
            }
            .sheet(isPresented: $showPaywall) {
                GWPaywallView()
            }
    }
}

extension View {
    /// Adds automatic paywall presentation when GWShowPaywall notification fires.
    func paywallListener() -> some View {
        modifier(GWPaywallModifier())
    }
}
