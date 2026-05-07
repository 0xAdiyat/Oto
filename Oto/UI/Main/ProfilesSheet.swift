import SwiftUI

struct ProfilesSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var newIcon: String = "grid-2x2"

    private let iconChoices = [
        "grid-2x2", "briefcase", "gamepad-2", "headphones",
        "music", "mic", "moon-star", "user-round"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profiles").font(.title2).bold()
            Text("Group related rules and switch between them — e.g. Work, Gaming, Recording. Rules without a profile are always active.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                if state.store.profiles.isEmpty {
                    Text("No profiles yet.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(state.store.profiles) { p in
                        profileRow(p)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Add a profile").font(.headline)
                HStack(spacing: 8) {
                    Picker("", selection: $newIcon) {
                        ForEach(iconChoices, id: \.self) { icon in
                            OtoIcon(name: icon, size: 14).tag(icon)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    TextField("Profile name (e.g. Work)", text: $newName)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        state.store.addProfile(Profile(name: trimmed, icon: newIcon))
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520)
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: 10) {
            OtoIcon(name: profile.icon, size: 14)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(Color.accentColor)
            TextField("Name", text: Binding(
                get: { profile.name },
                set: { newValue in
                    var updated = profile
                    updated.name = newValue
                    state.store.updateProfile(updated)
                }
            ))
            .textFieldStyle(.plain)
            Spacer()
            Text("\(state.store.rules.filter { $0.profileID == profile.id }.count) rules")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                state.store.deleteProfile(profile)
            } label: {
                OtoIcon(name: "trash-2", size: 14)
            }
            .buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}
