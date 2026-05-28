/// Core-side seam for the latest raw HEALTH signals. The real HKHealthStore-backed
/// implementation lives in NeonSaga/Services/ (Stage 1 Slice 5). Async because the real
/// reader queries HealthKit asynchronously; throwing so a fetch failure (permissions
/// undetermined, device locked, HK database error) is distinguishable from "no samples"
/// (all-`nil` metrics) — a conformer that cannot fail may still implement it non-throwing.
public protocol HealthDataSource {
    func latestMetrics() async throws -> HealthMetrics
}
