import Foundation

/// One stored snippet. `value` is a plain String so it covers both short fields
/// (an IBAN) and multi-line notes — no second model needed.
public struct Entry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var value: String
    public var category: String?
    /// Whether the value is masked (••••••) in the dropdown until clicked.
    public var masked: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        value: String,
        category: String? = nil,
        masked: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.value = value
        self.category = category
        self.masked = masked
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Exactly what gets encrypted to disk.
public struct Vault: Codable, Equatable, Sendable {
    public var entries: [Entry]
    public var schemaVersion: Int

    public init(entries: [Entry] = [], schemaVersion: Int = Vault.currentSchemaVersion) {
        self.entries = entries
        self.schemaVersion = schemaVersion
    }

    public static let currentSchemaVersion = 1
}
