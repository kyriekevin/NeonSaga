import Foundation
import NeonSagaCore
import SwiftData

@MainActor final class HealthSnapshotStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ snapshot: HealthSnapshot) throws {
        context.insert(HealthSnapshotRecord(from: snapshot))
        try context.save()
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
        context.insert(record)
        try context.save()
        return record
    }
}
