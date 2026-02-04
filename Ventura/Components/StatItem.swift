import SwiftData
import SwiftUI

struct StatItem: View {
    let icon: String
    let color: Color
    let label: String
    let value: String
    
    @ScaledMetric(relativeTo: .caption) private var iconSize: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var valueSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: valueSize, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            
            Text(label)
                .font(.system(size: labelSize, weight: .black))
                .foregroundStyle(.secondary.opacity(0.6))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let container = PreviewHelper.makeContainer()
    let descriptor = FetchDescriptor<Session>()
    let sessions = try? container.mainContext.fetch(descriptor)
    let session = sessions?.first

    return ScrollView {
        VStack(spacing: 30) {
            Group {
                Text("Live State (Home Set)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    isLive: true,
                    showHomeStats: true
                )

                Text("Live State (No Home)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    isLive: true,
                    showHomeStats: false
                )
            }

            Divider()

            Group {
                Text("Completed (Home Set)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    isLive: false,
                    showHomeStats: true
                )

                Text("Completed (No Home)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(
                    session: session,
                    isLive: false,
                    showHomeStats: false
                )
            }

            Divider()

            Group {
                Text("Empty State")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                SessionStatsCard(session: nil)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
