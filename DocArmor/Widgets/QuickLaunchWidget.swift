import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Intent Configuration

struct QuickLaunchIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Document Type"
    static let description = IntentDescription("Choose which document type to quick-launch.")

    @Parameter(title: "Document Type", default: nil)
    var documentType: DocumentTypeEntity?
}

// MARK: - Timeline Provider

struct QuickLaunchEntry: TimelineEntry {
    let date: Date
    let documentTypeName: String
    let documentTypeIcon: String
    let deepLinkURL: URL
}

struct QuickLaunchProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickLaunchEntry {
        makeEntry(for: .driversLicense)
    }

    func snapshot(for configuration: QuickLaunchIntent, in context: Context) async -> QuickLaunchEntry {
        let type = configuration.documentType?.documentType ?? .driversLicense
        return makeEntry(for: type)
    }

    func timeline(for configuration: QuickLaunchIntent, in context: Context) async -> Timeline<QuickLaunchEntry> {
        let type = configuration.documentType?.documentType ?? .driversLicense
        let entry = makeEntry(for: type)
        // Static content — no refresh needed
        return Timeline(entries: [entry], policy: .never)
    }

    private func makeEntry(for type: DocumentType) -> QuickLaunchEntry {
        let encoded = type.rawValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "docarmor://open?type=\(encoded)"
        // Fall back to the bare app URL rather than force-unwrapping; a future
        // DocumentType raw value could theoretically produce an invalid URL string.
        let deepLink = URL(string: urlString) ?? URL(string: "docarmor://open")!
        return QuickLaunchEntry(
            date: .now,
            documentTypeName: type.rawValue,
            documentTypeIcon: type.systemImage,
            deepLinkURL: deepLink
        )
    }
}

// MARK: - Widget View

struct QuickLaunchWidgetView: View {
    let entry: QuickLaunchEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Link(destination: entry.deepLinkURL) {
            ZStack {
                // Background
                ContainerRelativeShape()
                    .fill(.black)

                VStack(spacing: family == .systemSmall ? 8 : 12) {
                    // Shield + doc icon stack
                    ZStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: family == .systemSmall ? 32 : 42))
                            .foregroundStyle(.tint)

                        Image(systemName: entry.documentTypeIcon)
                            .font(.system(size: family == .systemSmall ? 11 : 14))
                            .foregroundStyle(.white)
                            .offset(y: family == .systemSmall ? 4 : 6)
                    }

                    VStack(spacing: 2) {
                        Text("DocArmor")
                            .font(.caption2.bold())
                            .foregroundStyle(.white.opacity(0.5))

                        Text(entry.documentTypeName)
                            .font(family == .systemSmall ? .caption.bold() : .subheadline.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Lock Screen (Accessory Circular) View

struct QuickLaunchAccessoryView: View {
    let entry: QuickLaunchEntry

    var body: some View {
        Link(destination: entry.deepLinkURL) {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
            }
        }
    }
}

// MARK: - Widget Definition

struct QuickLaunchWidget: Widget {
    let kind = "DocArmorQuickLaunch"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: QuickLaunchIntent.self,
            provider: QuickLaunchProvider()
        ) { entry in
            Group {
                switch entry.documentTypeName {
                default:
                    QuickLaunchWidgetView(entry: entry)
                }
            }
            .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("DocArmor Quick Launch")
        .description("Quickly open a document type in DocArmor.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Readiness Widget

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let snapshot: VaultReadinessSnapshot
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(
            date: .now,
            snapshot: VaultReadinessSnapshot(
                updatedAt: .now,
                totalDocuments: 6,
                needsAttentionCount: 2,
                expiringSoonCount: 1,
                readyNowCount: 4
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(ReadinessEntry(date: .now, snapshot: VaultSnapshotStore.loadSnapshot() ?? placeholder(in: context).snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = ReadinessEntry(date: .now, snapshot: VaultSnapshotStore.loadSnapshot() ?? placeholder(in: context).snapshot)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }
}

struct ReadinessWidgetView: View {
    let entry: ReadinessEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Vault Readiness", systemImage: "bolt.shield.fill")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack {
                readinessMetric("Ready", value: "\(entry.snapshot.readyNowCount)")
                readinessMetric("Alert", value: "\(entry.snapshot.needsAttentionCount)")
                readinessMetric("Soon", value: "\(entry.snapshot.expiringSoonCount)")
            }

            Text("Updated \(entry.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .containerBackground(Color(.systemGray6), for: .widget)
    }

    private func readinessMetric(_ title: String, value: String) -> some View {
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

struct ReadinessWidget: Widget {
    let kind = "DocArmorReadiness"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Vault Readiness")
        .description("See expiring and attention-needed documents at a glance.")
        .supportedFamilies([.systemMedium])
    }
}
