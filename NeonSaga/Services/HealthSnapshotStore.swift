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
        // Step 1: fetch raw metrics.
        let metrics = try await source.latestMetrics()

        // Step 2: compute the stat-day label (y,m,d) of `date` in `timeZone`.
        let writeLabel = statDayLabel(of: date, in: timeZone)

        // Step 3: upsert — find an existing record whose stat-day label matches.
        let existing = try allRecords().first { rec in
            let zone =
                rec.captureTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) }
                ?? calendar.timeZone
            return statDayLabel(of: rec.capturedAt, in: zone) == writeLabel
        }

        let affected: HealthSnapshotRecord
        if let rec = existing {
            // Overwrite raw metrics + identity fields; accumulated values filled below.
            rec.capturedAt = date
            rec.storedAt = Date()
            rec.captureTimeZoneIdentifier = timeZone.identifier
            rec.restingHeartRate = metrics.restingHeartRate
            rec.hrvRMSSD = metrics.hrvRMSSD
            rec.sleepEfficiency = metrics.sleepEfficiency
            rec.activeWorkoutEnergyKilocalories = metrics.activeWorkoutEnergyKilocalories
            affected = rec
        } else {
            // Insert a fresh record; accumulated values set in step 5.
            let rec = HealthSnapshotRecord(
                capturedAt: date, metrics: metrics,
                hunger: 0, fatigue: 0, strength: 0,
                captureTimeZoneIdentifier: timeZone.identifier)
            context.insert(rec)
            affected = rec
        }

        // Step 4: save raw metrics before reading baselines.
        try context.save()

        // Step 5: re-derive the accumulated suffix (full chain from index 0 — simple + correct).
        try reAccumulateAll(affected: affected)

        // Step 6: save accumulated values.
        try context.save()

        return affected
    }

    // MARK: - Private accumulation helpers

    /// Computes the `(year, month, day)` label of `date` in `zone`.
    private func statDayLabel(of date: Date, in zone: TimeZone) -> DateComponents {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        let dc = cal.dateComponents([.year, .month, .day], from: date)
        return dc
    }

    /// Builds a `HealthMetrics` value from the raw fields stored on a record.
    private func metricsFrom(_ rec: HealthSnapshotRecord) -> HealthMetrics {
        HealthMetrics(
            restingHeartRate: rec.restingHeartRate,
            hrvRMSSD: rec.hrvRMSSD,
            sleepEfficiency: rec.sleepEfficiency,
            activeWorkoutEnergyKilocalories: rec.activeWorkoutEnergyKilocalories)
    }

    /// Re-derives accumulated values for every record from index 0 to the end, in
    /// ascending `capturedAt` order. Rebuilds the full chain so back-fills are correct.
    private func reAccumulateAll(affected _: HealthSnapshotRecord) throws {
        let records = try allRecords()
        var prior: HealthSnapshotRecord? = nil
        for rec in records {
            let input = try DailyHealthInput.derive(
                from: metricsFrom(rec),
                hrvBaseline: recentHRVBaseline(before: rec.capturedAt),
                at: rec.capturedAt)

            if let prev = prior {
                let elapsed = rec.capturedAt.timeIntervalSince(prev.capturedAt) / 86_400.0
                rec.strengthValue = EWMA.accumulate(
                    previous: prev.strengthValue, dailyInput: input.strength,
                    elapsedDays: elapsed, halfLifeDays: HealthAccumulation.strengthHalfLifeDays)
                rec.fatigueValue = EWMA.accumulate(
                    previous: prev.fatigueValue, dailyInput: input.fatigue,
                    elapsedDays: elapsed, halfLifeDays: HealthAccumulation.fatigueHalfLifeDays)
                rec.hungerValue = EWMA.accumulate(
                    previous: prev.hungerValue, dailyInput: input.hunger,
                    elapsedDays: elapsed, halfLifeDays: HealthAccumulation.hungerHalfLifeDays)
            } else {
                // Cold start: seed accumulated = daily input.
                rec.strengthValue = input.strength
                rec.fatigueValue = input.fatigue
                rec.hungerValue = input.hunger
            }
            prior = rec
        }
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
