import NeonSagaCore
import SwiftData
import SwiftUI

// MARK: - Entry point (reads environment once)

struct HealthDetailView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HealthDetailContentView(store: HealthSnapshotStore(context: modelContext))
    }
}

// MARK: - Content (owns the view model)

private struct HealthDetailContentView: View {
    @State private var viewModel: HealthDetailViewModel

    init(store: HealthSnapshotStore) {
        _viewModel = State(initialValue: HealthDetailViewModel(store: store))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                RecoveryCard(viewModel: viewModel)
                SleepCard(placeholder: viewModel.sleepPlaceholder)
                StrainCard(viewModel: viewModel)
                SubStatsCard(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
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
                    .foregroundStyle(bandColor(band))
                Text(bandLabel(band))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(bandColor(band))
            }
        }
    }

    private func bandColor(_ band: RecoveryBand) -> Color {
        switch band {
        case .red: return Color(red: 1, green: 0.2, blue: 0.4)
        case .yellow: return Color.yellow
        case .green: return Color.cyan
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
        switch band {
        case .red: return Color(red: 1, green: 0.2, blue: 0.4)
        case .yellow: return Color.yellow
        case .green: return Color.cyan
        }
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

// MARK: - Sleep placeholder card

private struct SleepCard: View {
    let placeholder: String

    var body: some View {
        VStack(spacing: 8) {
            Text("SLEEP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.cyan)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(placeholder)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(white: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
