import NeonSagaCore
import SwiftData
import SwiftUI

// MARK: - Entry point (reads environment once)

struct HealthDetailView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HealthDetailContainerView(store: HealthSnapshotStore(context: modelContext))
    }
}

// MARK: - Container (instantiates the view model exactly once)

// `State(initialValue:)` evaluates its argument on every `init`, so constructing the
// view model there re-runs its synchronous store fetch on every parent body pass.
// Building it lazily in `.onAppear` on an optional `@State` guarantees a single
// construction + fetch, regardless of how often the parent re-evaluates.
private struct HealthDetailContainerView: View {
    let store: HealthSnapshotStore
    @State private var viewModel: HealthDetailViewModel?

    var body: some View {
        if let viewModel {
            HealthDetailContentView(viewModel: viewModel)
        } else {
            Color.black
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .onAppear { viewModel = HealthDetailViewModel(store: store) }
        }
    }
}

// MARK: - Content (renders the card stack)

private struct HealthDetailContentView: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RecoveryCard(viewModel: viewModel)
                SleepCard(viewModel: viewModel)
                StrainCard(viewModel: viewModel)
                SubStatsCard(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { viewModel.refresh() }
        .overlay { LevelUpTakeoverView(viewModel: viewModel) }
    }
}

// MARK: - Recovery hero card

private struct RecoveryCard: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("RECOVERY")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                RecoveryRing(viewModel: viewModel)
                VStack(alignment: .leading, spacing: 6) {
                    recoveryLabel
                    Divider().background(Color.gray.opacity(0.4))
                    Text(viewModel.aiBriefPlaceholder)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var recoveryLabel: some View {
        switch viewModel.recovery {
        case .calibrating(let days):
            Text("Calibrating — \(days)/14 days")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        case .scored(let value, let band):
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f", value))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(band.color)
                Text(bandLabel(band))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(band.color)
            }
        }
    }

    private func bandLabel(_ band: RecoveryBand) -> String {
        switch band {
        case .red: return "RED"
        case .yellow: return "YELLOW"
        case .green: return "GREEN"
        }
    }
}

// MARK: - Recovery ring

private struct RecoveryRing: View {
    let viewModel: HealthDetailViewModel

    private var ringColor: Color {
        guard case .scored(_, let band) = viewModel.recovery else { return .gray }
        return band.color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 8)
            Circle()
                .trim(from: 0, to: viewModel.recoveryRingFraction ?? 0)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Sleep architecture card

private struct SleepCard: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("SLEEP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch viewModel.sleep {
            case .noData:
                Text("No sleep data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case .scored(let s):
                SleepScoredBody(summary: s)
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SleepScoredBody: View {
    let summary: SleepSummary

    private func formatMinutes(_ total: Double) -> String {
        let h = Int(total) / 60
        let m = Int(total) % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Total asleep
            Text(formatMinutes(summary.asleepMinutes))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            // Stage rows
            SleepStageRow(label: "Deep", minutes: summary.deepMinutes, color: .indigo)
            SleepStageRow(label: "REM", minutes: summary.remMinutes, color: .purple)
            SleepStageRow(label: "Light", minutes: summary.lightMinutes, color: .cyan)

            // Proportional stacked bar
            SleepStackedBar(summary: summary)

            // Time in bed + efficiency (when present)
            if let bed = summary.timeInBedMinutes {
                let effText: String = {
                    if let e = summary.efficiency {
                        return String(format: " · %.0f%% efficiency", e * 100)
                    }
                    return ""
                }()
                Text("In bed: \(formatMinutes(bed))\(effText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Wake events (when present)
            if let wake = summary.wakeEvents {
                Text("Wake events: \(wake)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SleepStageRow: View {
    let label: String
    let minutes: Double
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
                .frame(width: 44, alignment: .leading)
            Text(minutesText(minutes))
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func minutesText(_ m: Double) -> String {
        let h = Int(m) / 60
        let mins = Int(m) % 60
        if h > 0 { return "\(h)h \(mins)m" }
        return "\(mins)m"
    }
}

private struct SleepStackedBar: View {
    let summary: SleepSummary

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.indigo)
                    .frame(width: max(geo.size.width * summary.deepFraction - 1, 0))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.purple)
                    .frame(width: max(geo.size.width * summary.remFraction - 1, 0))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.cyan)
                    .frame(width: max(geo.size.width * summary.lightFraction - 1, 0))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Strain card

private struct StrainCard: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        VStack(spacing: 8) {
            Text("STRAIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)

            switch viewModel.strain {
            case .noData:
                Text("No workout data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .scored(let value):
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", value))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.yellow)
                    Text("/ 21")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let fraction = viewModel.strainFraction {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.1))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.yellow)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - HEALTH sub-stats card

private struct SubStatsCard: View {
    let viewModel: HealthDetailViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("HEALTH")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.cyan)
                Spacer()
                if let hv = viewModel.healthValue, let hl = viewModel.healthLevel {
                    Text(String(format: "%.0f", hv))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.cyan)
                    Text("LV \(hl)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.hasData {
                ForEach(viewModel.subStats) { row in
                    SubStatBarRow(row: row)
                }
            } else {
                Text("No health data yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct SubStatBarRow: View {
    let row: SubStatRow

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(substatLabel(row.substat))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                Spacer()
                Text(String(format: "%.0f", row.value))
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text("LV \(row.level)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.cyan)
                        .frame(width: geo.size.width * row.fillFraction)
                }
            }
            .frame(height: 6)
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

// MARK: - Band → HUD color

extension RecoveryBand {
    /// Neon HUD accent color for each recovery band.
    var color: Color {
        switch self {
        case .red: return Color(red: 1, green: 0.2, blue: 0.4)
        case .yellow: return .yellow
        case .green: return .cyan
        }
    }
}
