import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: ShopStore
    @EnvironmentObject private var analytics: AppAnalytics

    var body: some View {
        NavigationStack {
            List {
                if let user = store.user {
                    Section("Signed in") {
                        LabeledContent("Name", value: user.displayName)
                        LabeledContent("User id (sent)", value: user.id)
                        LabeledContent("Plan", value: user.plan)
                        LabeledContent("Country", value: user.country)
                        LabeledContent("Age group", value: user.ageGroup)
                        Button("Log out", role: .destructive) { store.logout() }
                    }
                } else {
                    Section("Sign in as a demo user") {
                        ForEach(DemoUser.all) { user in
                            Button {
                                store.login(user)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(user.displayName).font(.headline)
                                    Text("\(user.plan) plan, \(user.country), age \(user.ageGroup)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    Toggle("Allow analytics", isOn: Binding(
                        get: { analytics.consentGranted },
                        set: { value in Task { await analytics.setConsent(value) } }))
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Switching this off stops recording and deletes events that were not sent yet. "
                         + "Only an opaque user id and traits such as plan and country are sent. Names and e-mail addresses are not.")
                }
            }
            .navigationTitle("Profile")
            .onAppear { analytics.screen("Profile") }
        }
    }
}
