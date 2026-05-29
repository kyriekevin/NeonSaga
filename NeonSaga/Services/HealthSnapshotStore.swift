import Foundation
import NeonSagaCore
import SwiftData

@MainActor final class HealthSnapshotStore {
    private let context: ModelContext
    /// Nil-fallback zone for stat-day label computation when a record has no stored
    /// `captureTimeZoneIdentifier`; tests inject a fixed zone for determinism (S6b).
    private let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// Low-level persistence seam: insert a pre-built record then save. The
    /// accumulation math lives in `deriveAndStore`; this just persists.
    func save(_ record: HealthSnapshotRecord) throws {
        try insertAndSave(record)
    }

    func latest() throws -> HealthSnapshotRecord? {
        var descriptor = FetchDescriptor<HealthSnapshotRecord>(
            sortBy: [
                SortDescriptor(\.capturedAt, order: .reverse),
                SortDescriptor(\.storedAt, order: .reverse),
            ])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// All records ascending by `capturedAt` (then `storedAt`) — used by the
    /// accumulation suffix re-derive (GREEN) and by tests.
    func allRecords() throws -> [HealthSnapshotRecord] {
        try context.fetch(
            FetchDescriptor<HealthSnapshotRecord>(
                sortBy: [SortDescriptor(\.capturedAt), SortDescriptor(\.storedAt)]))
    }

    /// Derives today's `DailyHealthInput`, accumulates it (time-aware EWMA) onto the
    /// carried-forward stored values, upserts ONE record per local-calendar stat-day
    /// (label `(y,m,d)` in `capturedIn`), and re-derives the affected suffix on
    /// out-of-order / back-filled inputs. See ADR-002 / the S6b CONTRACT.
    @discardableResult
    func deriveAndStore(
        from source: HealthDataSource, at date: Date, capturedIn timeZone: TimeZone = .current
    ) async throws -> HealthSnapshotRecord {
        let metrics = try await source.latestMetrics()
        // S6b RED stub — GREEN implements stat-day upsert + EWMA accumulation + suffix
        // re-derive. This naive insert (stores the daily input directly, never
        // accumulates, never upserts) fails the accumulation / upsert / back-fill /
        // timezone tests so `make test` stays red until the real body lands.
        let input = DailyHealthInput.derive(
            from: metrics, hrvBaseline: try recentHRVBaseline(before: date), at: date)
        let record = HealthSnapshotRecord(
            capturedAt: date, metrics: metrics,
            hunger: input.hunger, fatigue: input.fatigue, strength: input.strength,
            captureTimeZoneIdentifier: timeZone.identifier)
        try insertAndSave(record)
        return record
    }

    /// Returns the finite HRV values from records strictly older than `capturedAt`,
    /// newest-first, limited to `limit`. The strict `<` excludes the record being
    /// scored, so today's HRV is never folded into its own baseline (Codex B2 / S6).
    func recentHRVBaseline(before capturedAt: Date, limit: Int = 28) throws -> [Double] {
        var descriptor = FetchDescriptor<HealthSnapshotRecord>(
            predicate: #Predicate { $0.capturedAt < capturedAt },
            sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let records = try context.fetch(descriptor)
        return records.compactMap { $0.hrvRMSSD }.filter { $0.isFinite }
    }

    /// Inserts `record` then saves. On save failure, drops the pending insert so a
    /// stale record can't be retried by a later write, then rethrows.
    private func insertAndSave(_ record: HealthSnapshotRecord) throws {
        context.insert(record)
        do {
            try context.save()
        } catch {
            context.delete(record)
            throw error
        }
    }
}
