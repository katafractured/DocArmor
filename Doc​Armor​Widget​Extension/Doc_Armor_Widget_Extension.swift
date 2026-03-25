//
//  Doc_Armor_Widget_Extension.swift
//  Doc​Armor​Widget​Extension
//
//  Created by Christian Flores on 3/24/26.
//

import WidgetKit
import SwiftUI
import AppIntents

enum WidgetAppGroup {
    static let identifier = "group.com.katafract.DocArmor"
}

struct WidgetVaultReadinessSnapshot: Codable {
    let updatedAt: Date
    let totalDocuments: Int
    let needsAttentionCount: Int
    let expiringSoonCount: Int
    let readyNowCount: Int
}

enum WidgetSnapshotStore {
    static func load() -> WidgetVaultReadinessSnapshot {
        guard
            let defaults = UserDefaults(suiteName: WidgetAppGroup.identifier),
            let data = defaults.data(forKey: "vaultReadinessSnapshot"),
            let snapshot = try? JSONDecoder().decode(WidgetVaultReadinessSnapshot.self, from: data)
        else {
            return WidgetVaultReadinessSnapshot(
                updatedAt: .now,
                totalDocuments: 0,
                needsAttentionCount: 0,
                expiringSoonCount: 0,
                readyNowCount: 0
            )
        }
        return snapshot
    }
}

enum QuickLaunchType: String, CaseIterable, Identifiable {
    case driversLicense = "Driver's License"
    case passport = "Passport"
    case insuranceHealth = "Health Insurance"
    case medical = "Medical Go-Bag"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .driversLicense: return "car.fill"
        case .passport: return "globe"
        case .insuranceHealth: return "cross.fill"
        case .medical: return "heart.text.square.fill"
        }
    }

    var deepLink: URL {
        switch self {
        case .medical:
            return URL(string: "docarmor://open")!
        default:
            let encoded = rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "docarmor://open?type=\(encoded)")!
        }
    }
}

struct QuickLaunchEntry: TimelineEntry {
    let date: Date
    let type: QuickLaunchType
}

struct QuickLaunchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickLaunchEntry {
        QuickLaunchEntry(date: .now, type: .driversLicense)
    }

    func snapshot(for configuration: QuickLaunchIntent, in context: Context) async -> QuickLaunchEntry {
        QuickLaunchEntry(date: .now, type: configuration.quickLaunchType)
    }

    func timeline(for configuration: QuickLaunchIntent, in context: Context) async -> Timeline<QuickLaunchEntry> {
        Timeline(entries: [QuickLaunchEntry(date: .now, type: configuration.quickLaunchType)], policy: .never)
    }
}

struct QuickLaunchIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Launch"
    static let description = IntentDescription("Choose a document shortcut for the widget.")

    @Parameter(title: "Document")
    var document: QuickLaunchTypeEntity?

    var quickLaunchType: QuickLaunchType {
        document?.type ?? .driversLicense
    }
}

struct QuickLaunchTypeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Quick Launch Type")
    static let defaultQuery = QuickLaunchTypeQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id))
    }

    var type: QuickLaunchType {
        QuickLaunchType(rawValue: id) ?? .driversLicense
    }
}

struct QuickLaunchTypeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [QuickLaunchTypeEntity] {
        QuickLaunchType.allCases
            .filter { identifiers.contains($0.rawValue) }
            .map { QuickLaunchTypeEntity(id: $0.rawValue) }
    }

    func suggestedEntities() async throws -> [QuickLaunchTypeEntity] {
        QuickLaunchType.allCases.map { QuickLaunchTypeEntity(id: $0.rawValue) }
    }
}

struct DocArmorQuickLaunchWidget: Widget {
    let kind = "DocArmorQuickLaunchWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickLaunchIntent.self, provider: QuickLaunchProvider()) { entry in
            Link(destination: entry.type.deepLink) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tint)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: entry.type.systemImage)
                                .font(.system(size: 13))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(.black.opacity(0.55)))
                        }

                    Text(entry.type.rawValue)
                        .font(.caption.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
            .containerBackground(Color(.systemGray6), for: .widget)
        }
        .configurationDisplayName("DocArmor Quick Launch")
        .description("Open a frequently used document from the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetVaultReadinessSnapshot
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(
            date: .now,
            snapshot: WidgetVaultReadinessSnapshot(
                updatedAt: .now,
                totalDocuments: 6,
                needsAttentionCount: 2,
                expiringSoonCount: 1,
                readyNowCount: 4
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(ReadinessEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = ReadinessEntry(date: .now, snapshot: WidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800))))
    }
}

struct DocArmorReadinessWidget: Widget {
    let kind = "DocArmorReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                Label("Vault Readiness", systemImage: "bolt.shield.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                HStack {
                    readinessMetric(title: "Ready", value: "\(entry.snapshot.readyNowCount)")
                    readinessMetric(title: "Soon", value: "\(entry.snapshot.expiringSoonCount)")
                    readinessMetric(title: "Alert", value: "\(entry.snapshot.needsAttentionCount)")
                }

                Text("Total documents: \(entry.snapshot.totalDocuments)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .containerBackground(Color(.systemGray6), for: .widget)
        }
        .configurationDisplayName("Vault Readiness")
        .description("Monitor document readiness and upcoming issues.")
        .supportedFamilies([.systemMedium])
    }

    private func readinessMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    DocArmorQuickLaunchWidget()
} timeline: {
    QuickLaunchEntry(date: .now, type: .driversLicense)
}
