import NeonSagaCore
import SwiftUI

// MARK: - Level-up takeover overlay

/// Full-screen Cyberpunk-HUD overlay that plays while `viewModel.currentLevelUp != nil`.
///
/// Presentation contract (ADR-003 Layer-0):
/// - Reads the singleton VM passed in — never constructs a new VM instance.
/// - All queue/dismiss business logic lives in the VM; this view only presents and
///   schedules the 0.8-second auto-dismiss.
/// - Haptic: SwiftUI `.sensoryFeedback(.success, ...)` keyed off the crossing identity
///   (iOS 18 target; no UIKit / CoreHaptics import).
/// - Auto-dismiss: `.task(id:)` sleeps 0.8 s then calls `dismissCurrentLevelUp()`.
///   The task is cancelled automatically when the id changes (next crossing) or the
///   view disappears, so stacked crossings play sequentially without overlap.
///
/// Sound: deferred per ROADMAP §2 Plan B L4 (placeholder)
struct LevelUpTakeoverView: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        if let crossing = viewModel.currentLevelUp {
            // `.id(crossing)` gives each queued crossing a fresh view identity, so the
            // scale/opacity intro AND the success haptic re-fire per crossing (the
            // baseline update in the VM makes identical consecutive crossings unreachable,
            // so the crossing value alone is a sufficient id — Codex diff-review item 3).
            TakeoverCard(crossing: crossing, onDismiss: { viewModel.dismissCurrentLevelUp() })
                .id(crossing)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: crossing)
        }
    }
}

// MARK: - TakeoverCard

private struct TakeoverCard: View {
    let crossing: SubStatLevelCrossing
    let onDismiss: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("LEVEL UP")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.cyan)
                    .shadow(color: Color.cyan.opacity(0.7), radius: 12)

                Text(substatLabel(crossing.substat))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.85))

                Text("LV \(crossing.crossing.oldLevel) → \(crossing.crossing.newLevel)")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.9))
            }
            .scaleEffect(visible ? 1.0 : 0.8)
            .opacity(visible ? 1.0 : 0.0)
            .animation(.spring(duration: 0.35), value: visible)
        }
        // Trigger the haptic off `visible` (false→true on appear), NOT off `crossing`:
        // `.sensoryFeedback` fires on a CHANGE, not on first appearance, so a fixed
        // per-card `crossing` trigger would never fire. The appear-time flip guarantees one
        // success haptic each time a (freshly `.id`-ed) card mounts (Codex diff-review item 3).
        .sensoryFeedback(.success, trigger: visible)
        .onAppear { visible = true }
        .task(id: crossing) {
            do {
                try await Task.sleep(for: .seconds(0.8))
                onDismiss()
            } catch {
                // Task cancelled (crossing changed or view disappeared) — no-op.
            }
        }
    }

    private func substatLabel(_ substat: SubStat) -> String {
        switch substat {
        case .hunger: return "HUNGER"
        case .fatigue: return "FATIGUE"
        case .strength: return "STRENGTH"
        }
    }
}
