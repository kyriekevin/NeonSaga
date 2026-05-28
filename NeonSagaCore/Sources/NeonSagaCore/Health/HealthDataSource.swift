/// Core-side seam for the latest raw HEALTH signals. The real HKHealthStore-backed
/// implementation lives in NeonSaga/Services/ (Stage 1 Slice 5). Async because the
/// real reader queries HealthKit asynchronously.
public protocol HealthDataSource {
    func latestMetrics() async -> HealthMetrics
}
