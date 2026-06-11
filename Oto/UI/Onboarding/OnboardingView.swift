import SwiftUI

/// Three-step first-run wizard, modelled on the LookAway onboarding flow:
///   1. Set Your Break Routine — focus interval + break length
///   2. Set Up Wellness Reminders — posture / blink cadence
///   3. You're All Set! — summary + launch-at-login + jump to settings
///
/// Choices write straight through to `WellnessStore.settings` (which persists +
/// reschedules the engine), so the step-3 preview reflects the user's picks
/// live. Presented in a titled window by `OnboardingWindowController`.
struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @Environment(\.openSettings) private var openSettings

    @State private var step = 0
    @State private var reminderKind: ReminderKind = .posture

    private enum ReminderKind: Hashable { case posture, blink }
    private let stepCount = 3

    var body: some View {
        @Bindable var store = state.wellness

        VStack(spacing: 0) {
            content(store: $store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.top, 36)

            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
        }
        .frame(width: 880, height: 620)
        .background {
            ZStack {
                // Real macOS vibrancy — translucent material over the desktop,
                // not a flat fill.
                VisualEffectBackground(material: .hudWindow)
                // Soft accent glow behind the header, echoing the reference's
                // top-center bloom (Oto's teal instead of LookAway's magenta).
                RadialGradient(
                    colors: [Color.otoTeal.opacity(0.22), .clear],
                    center: .top, startRadius: 0, endRadius: 380
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .focusEffectDisabled()
        .suppressAppKitFocusRings()
    }

    // MARK: - Step content

    @ViewBuilder
    private func content(store: Bindable<WellnessStore>) -> some View {
        Group {
            switch step {
            case 0: breakRoutineStep(store: store)
            case 1: remindersStep(store: store)
            default: allSetStep()
            }
        }
        .id(step)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(x: 16)),
            removal: .opacity.combined(with: .offset(x: -16))
        ))
        .animation(.easeOut(duration: 0.22), value: step)
    }

    // MARK: Step 1 — Break routine

    private func breakRoutineStep(store: Bindable<WellnessStore>) -> some View {
        VStack(spacing: 26) {
            stepHeader(icon: "leaf.fill", tint: .otoTeal, title: "Set Your Break Routine")

            HStack(alignment: .top, spacing: 16) {
                settingsCard(
                    title: "Time between breaks",
                    description: "Choose how long you work before Oto starts a break. You can delay it if needed."
                ) {
                    OptionChipGrid(
                        options: WellnessPresets.breakIntervals.map {
                            ($0, WellnessPresets.intervalLabel(minutes: $0))
                        },
                        selection: store.settings.breakIntervalMinutes
                    )
                }
                settingsCard(
                    title: "Break length",
                    description: "Choose how long the break lasts while your screen gently blurs."
                ) {
                    OptionChipGrid(
                        options: WellnessPresets.breakLengths.map {
                            ($0, WellnessSettings.durationLabel(seconds: $0))
                        },
                        selection: store.settings.breakLengthSeconds
                    )
                }
            }
        }
    }

    // MARK: Step 2 — Wellness reminders

    private func remindersStep(store: Bindable<WellnessStore>) -> some View {
        let reminderBinding = Binding<Int>(
            get: {
                reminderKind == .posture
                    ? store.wrappedValue.settings.postureReminderMinutes
                    : store.wrappedValue.settings.blinkReminderMinutes
            },
            set: { newValue in
                // A non-zero cadence also flips the reminder on (the overlay
                // engine gates on the enabled flag now, not just the cadence).
                if reminderKind == .posture {
                    store.wrappedValue.settings.postureReminderMinutes = newValue
                    store.wrappedValue.settings.postureReminderEnabled = newValue > 0
                } else {
                    store.wrappedValue.settings.blinkReminderMinutes = newValue
                    store.wrappedValue.settings.blinkReminderEnabled = newValue > 0
                }
            }
        )

        return VStack(spacing: 22) {
            stepHeader(icon: "heart.fill", tint: .otoSage, title: "Set Up Wellness Reminders")

            SegmentedPill(
                items: [(.posture, "Posture Reminder"), (.blink, "Blink Reminder")],
                selection: $reminderKind
            )
            .fixedSize()

            HStack(alignment: .top, spacing: 16) {
                settingsCard(
                    title: nil,
                    description: reminderKind == .posture
                        ? "Helps maintain good posture by gently alerting you to sit upright and avoid strain."
                        : "Reminds you to blink regularly to keep your eyes from drying out during long sessions."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        OptionChipGrid(
                            options: WellnessPresets.reminderIntervals.map {
                                ($0, WellnessPresets.reminderLabel(minutes: $0))
                            },
                            selection: reminderBinding
                        )
                        Label("You can adjust these anytime in Settings", systemImage: "info.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(OtoUI.mutedFG)
                    }
                }

                illustrationPanel(
                    icon: reminderKind == .posture ? "figure.stand" : "eye",
                    tint: reminderKind == .posture ? .otoTeal : .otoSage
                )
            }
        }
    }

    // MARK: Step 3 — All set

    private func allSetStep() -> some View {
        VStack(spacing: 26) {
            stepHeader(icon: "hand.thumbsup.fill", tint: .otoYellow, title: "You're All Set!")

            HStack(alignment: .top, spacing: 16) {
                // Countdown preview
                cardShell {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your digital wellness starts now!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OtoUI.primaryFG)
                        Text(state.breakManager.clockUntilBreak)
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(OtoUI.primaryFG)
                        Text("We'll nudge you a minute before the break.")
                            .font(.system(size: 12))
                            .foregroundStyle(OtoUI.mutedFG)
                        Spacer(minLength: 0)
                        Button {
                            state.breakManager.startBreakNow()
                        } label: {
                            Label("Start break now", systemImage: "leaf")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.otoTeal)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Menu-bar hint
                cardShell {
                    VStack(spacing: 14) {
                        menuBarMock
                        Text("Control Oto from the menu bar")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OtoUI.secondaryFG)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Quick actions
                cardShell {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: Binding(
                            get: { LaunchAtLogin.isEnabled },
                            set: { LaunchAtLogin.setEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Start at login")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(OtoUI.secondaryFG)
                                Text("Oto will be ready when you are.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(OtoUI.mutedFG)
                            }
                        }
                        .toggleStyle(.switch)

                        Divider().background(OtoUI.dividerColor)

                        Button {
                            openSettings()
                        } label: {
                            HStack(spacing: 8) {
                                OtoIcon(name: "gearshape", size: 13).foregroundStyle(Color.otoTeal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("View settings")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(OtoUI.secondaryFG)
                                    Text("Tune Oto to fit your routine.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(OtoUI.mutedFG)
                                }
                                Spacer()
                                OtoIcon(name: "chevron.right", size: 10).foregroundStyle(OtoUI.mutedFG)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: 320)
        }
    }

    private var menuBarMock: some View {
        HStack(spacing: 5) {
            Image("MenuBarIcon").resizable().scaledToFit().frame(width: 14, height: 14)
            Text(state.breakManager.menuBarCountdown)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(OtoUI.rowIdle, in: Capsule())
        .overlay { Capsule().strokeBorder(OtoUI.dividerColor, lineWidth: 1) }
    }

    // MARK: - Shared chrome

    private func stepHeader(icon: String, tint: Color, title: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18))
                OtoIcon(name: icon, size: 22).foregroundStyle(tint)
            }
            .frame(width: 48, height: 48)
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(OtoUI.primaryFG)
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String?,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                if let title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OtoUI.primaryFG)
                }
                Text(description)
                    .font(.system(size: 12.5))
                    .foregroundStyle(OtoUI.mutedFG)
                    .fixedSize(horizontal: false, vertical: true)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func illustrationPanel(icon: String, tint: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [tint.opacity(0.30), tint.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle()
                .fill(tint.opacity(0.25))
                .frame(width: 76, height: 76)
                .overlay { OtoIcon(name: icon, size: 30).foregroundStyle(.white) }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private func cardShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(OtoUI.rowIdle, in: RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OtoSettingsUI.cardRadius, style: .continuous)
                    .strokeBorder(OtoUI.dividerColor, lineWidth: 1)
            }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            } else {
                Color.clear.frame(width: 1, height: 1)
            }

            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<stepCount, id: \.self) { i in
                    Circle()
                        .fill(i == step ? OtoUI.primaryFG : OtoUI.mutedFG.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()

            Button(step == stepCount - 1 ? "Close" : "Next") {
                if step == stepCount - 1 {
                    state.completeOnboarding()
                } else {
                    withAnimation { step += 1 }
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.otoTeal)
        }
    }
}

#if DEBUG
#Preview("Onboarding") {
    OnboardingView()
        .environment(AppState.previewPopulated)
        .preferredColorScheme(.dark)
}
#endif
