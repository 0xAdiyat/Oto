import SwiftUI

struct ProfilesSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var newIcon: String = "grid-2x2"

    private let iconChoices = [
        "grid-2x2", "briefcase", "gamepad-2", "headphones",
        "music", "mic", "moon-star", "user-round"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profiles")
                    .font(.system(size: OtoUI.titleSize, weight: .semibold))
                Text("Group related rules and switch between them — e.g. Work, Gaming, Recording. Rules without a profile are always active.")
                    .font(.system(size: 13))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 6) {
                if state.store.profiles.isEmpty {
                    Text("No profiles yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(OtoUI.mutedFG)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                } else {
                    ForEach(state.store.profiles) { p in
                        profileRow(p)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Add a profile")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OtoUI.mutedFG)
                HStack(spacing: 8) {
                    Picker("", selection: $newIcon) {
                        ForEach(iconChoices, id: \.self) { icon in
                            OtoIcon(name: icon, size: 14).tag(icon)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 80)

                    TextField("Profile name", text: $newName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        let trimmed = newName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        state.store.addProfile(Profile(name: trimmed, icon: newIcon))
                        newName = ""
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.otoTeal)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.otoTeal)
            }
        }
        .padding(26)
        .frame(width: 540)
        .materialPanel()
        .preferredColorScheme(.light)
    }

    private func profileRow(_ profile: Profile) -> some View {
        HStack(spacing: 12) {
            OtoIcon(name: profile.icon, size: 14)
                .frame(width: 32, height: 32)
                .background(OtoUI.iconTile, in: RoundedRectangle(cornerRadius: OtoUI.buttonRadius))
                .foregroundStyle(.primary.opacity(0.85))
            TextField("Name", text: Binding(
                get: { profile.name },
                set: { newValue in
                    var updated = profile
                    updated.name = newValue
                    state.store.updateProfile(updated)
                }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            Spacer()
            Text("\(state.store.rules.filter { $0.profileID == profile.id }.count) rules")
                .font(.system(size: 12))
                .foregroundStyle(OtoUI.mutedFG)
            IconButton(icon: "trash-2", iconSize: 13, help: "Delete") {
                state.store.deleteProfile(profile)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoUI.chipRadius))
    }
}
