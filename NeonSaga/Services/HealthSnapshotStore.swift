import Foundation
import NeonSagaCore
import SwiftData

@MainActor final class HealthSnapshotStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ snapshot: HealthSnapshot) throws {
        try insertAndSave(HealthSnapshotRecord(from: snapshot))
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

    @discardableResult
    func deriveAndStore(from source: HealthDataSource, at date: Date) async throws
        -> HealthSnapshotRecord
    {
        let metrics = try await source.latestMetrics()
        let snapshot = HealthSnapshot.derive(from: metrics, at: date)
        let record = HealthSnapshotRecord(from: snapshot)
        try insertAndSave(record)
        return record
    }

    /// Inserts `record` then saves. On save failure, drops the pending insert so
    /// a stale record can't be retried by a later `save()`, then rethrows the error.
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
