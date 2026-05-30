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

        // Step 3: upsert — find an existing record on the same stat-day. Scan only a
        // BOUNDED window around `date`, not the whole table (Gemini PR#13): a record
        // sharing the local date label, even in another capture zone, has its absolute
        // `capturedAt` within |zoneOffsetDiff| + 24h of `date`. Real zone offsets span
        // UTC-12…+14 (≤ 26h), so |Δ| ≤ 50h; a ±2.5-day (60h) window covers it with margin
        // while fetching only a handful of rows regardless of history size.
        let windowStart = date.addingTimeInterval(-2.5 * 86_400)
        let windowEnd = date.addingTimeInterval(2.5 * 86_400)
        let inWindow = #Predicate<HealthSnapshotRecord> {
            $0.capturedAt >= windowStart && $0.capturedAt <= windowEnd
        }
        let candidates = try context.fetch(
            FetchDescriptor<HealthSnapshotRecord>(predicate: inWindow))
        let existing = candidates.first { rec in
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
            rec.deepSleepMinutes = metrics.deepSleepMinutes
            rec.remSleepMinutes = metrics.remSleepMinutes
            rec.lightSleepMinutes = metrics.lightSleepMinutes
            rec.timeInBedMinutes = metrics.timeInBedMinutes
            rec.wakeEventsCount = metrics.wakeEventsCount
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

        // Re-derive the affected record + its suffix (records before it are already
        // correct), then persist raw + accumulated in a SINGLE save so there is no
        // partial-write window (Codex 2b). On failure, roll back so the context holds no
        // dangling uncommitted mutations (an insert is discarded; an upsert's raw overwrite
        // reverts) — leaving a consistent committed state.
        do {
            try reAccumulateSuffix(from: affected)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

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

    /// Re-derives accumulated values for `affected` and every LATER record (the suffix in
    /// ascending `capturedAt` order). Records BEFORE `affected` are already correct, so the
    /// write path is O(K) over the suffix (K = 1 for the common append) rather than O(N) over
    /// all history (Gemini PR#13). Back-fill is handled: an out-of-order insert is the suffix
    /// head, so every later record re-derives against it (both the EWMA chain and its HRV
    /// baseline window). The single record immediately before `affected` seeds the chain.
    private func reAccumulateSuffix(from affected: HealthSnapshotRecord) throws {
        // Fetch the full ordered list ONCE — `allRecords()` reflects the pending in-memory
        // insert/upsert (a `#Predicate` fetch on the just-mutated, unsaved `capturedAt`
        // does NOT, and silently mis-buckets the affected record). Re-derive only `affected`
        // and its suffix; the prefix is already correct, so only O(K) HRV-baseline queries
        // run (K = 1 for the common append) instead of one per record (Gemini PR#13).
        let records = try allRecords()
        guard let start = records.firstIndex(where: { $0 === affected }) else { return }
        var prior: HealthSnapshotRecord? = start > 0 ? records[start - 1] : nil
        for rec in records[start...] {
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
