import SwiftData
import SwiftUI

struct EarningsComparisonCard: View {
    // PERFORMANCE: Manual fetch instead of @Query to prevent
    // synchronous re-evaluation of ALL sessions on every app foreground resume.
    // @Query keeps an active observer that fires on every foreground transition,
    // and its .onChange(of: sessions) was triggering computeEarnings() cascading work.
    @Environment(\.modelContext) private var modelContext
    @State private var sessions: [Session] = []
    
    private func loadSessions() async {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let cutoffDate = Calendar.current.startOfDay(for: ninetyDaysAgo)
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { $0.startTimestamp >= cutoffDate },
            sortBy: [SortDescriptor(\.startTimestamp, order: .reverse)]
        )
        do {
            sessions = try modelContext.fetch(descriptor)
        } catch {
            print("EarningsComparisonCard: Failed to fetch sessions: \(error)")
        }
    }

    enum ComparisonPeriod: String, CaseIterable, Identifiable {
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var id: String { rawValue }

        var thisLabel: String {
            switch self {
            case .day: return "Today"
            case .week: return "This Week"
            case .month: return "This Month"
            }
        }
        
        var lastLabel: String {
            switch self {
            case .day: return "Yesterday"
            case .week: return "Last Week"
            case .month: return "Last Month"
            }
        }
    }

    @State private var selectedPeriod: ComparisonPeriod = .week
    @State private var currentAmount: Decimal = 0
    @State private var previousAmount: Decimal = 0
    @State private var isLoading = true



    var body: some View {
        let maxValue = max(
            Double(truncating: currentAmount as NSNumber),
            Double(truncating: previousAmount as NSNumber)
        )
        // Ensure we handle the 0 case to avoid division by zero
        let scaleMax = maxValue > 0 ? maxValue : 1.0

        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(.green)
                Text("Earnings Comparison")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()

                Menu {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ComparisonPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedPeriod.rawValue)
                            .font(.caption)
                            .fontWeight(.bold)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }

                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .opacity(isLoading ? 0.5 : 1)

            VStack(spacing: 12) {
                // Current Period Row
                EarningsBarRow(
                    label: selectedPeriod.thisLabel,
                    amount: currentAmount,
                    maxValue: scaleMax,
                    color: .green
                )

                // Previous Period Row
                EarningsBarRow(
                    label: selectedPeriod.lastLabel,
                    amount: previousAmount,
                    maxValue: scaleMax,
                    color: .blue
                )
            }
        }
        .padding()
        .glassModifier(in: RoundedRectangle(cornerRadius: 20))
        .task(id: selectedPeriod) {
            // Load sessions first (async, won't block main thread)
            await loadSessions()
            await computeEarnings()
        }
    }
    
    private func computeEarnings() async {
        // Run on background thread
        // print("Computing earnings for \(selectedPeriod.rawValue)")
        let period = selectedPeriod
        // Create local copy of simple data structures if needed, but managing sessions access is tricky across threads if they are model objects.
        // However, we can map to structs or access them on MainActor task but yield.
        // Accessing Query `sessions` property is MainActor bound.
        // We will create the filter logic here but keep it performant.
        // Since we are on MainActor (View body context), let's yield first to let UI render.
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms yield
        
        let helper = DateRangeHelper.shared
        let currentStart: Date
        let previousInterval: DateInterval

        switch period {
        case .day:
            currentStart = helper.startOfToday
            previousInterval = helper.lastDayInterval
        case .week:
            currentStart = helper.startOfCurrentWeek
            previousInterval = helper.lastWeekInterval
        case .month:
            currentStart = helper.startOfCurrentMonth
            previousInterval = helper.lastMonthInterval
        }
        
        // This filtering is still synchronous on MainActor. 
        // To truly fix a lag spike, we should fetch ONLY what we need or map it.
        // But we can limit the data processed.
        // The `sessions` array is already in memory.
        
        // Let's use a Task.detached? No, passing ModelObjects thread to thread is unsafe.
        // Best refactor: extract values (date + profit) to simple structs, THEN compute on background.
        
        let simpleSessions = sessions.map { (date: $0.startTimestamp, profit: $0.netProfit) }
        
        let result = await Task.detached(priority: .userInitiated) {
            let current = simpleSessions
                .filter { $0.date >= currentStart }
                .reduce(0) { $0 + $1.profit }
                
            let prev = simpleSessions
                .filter { previousInterval.contains($0.date) }
                .reduce(0) { $0 + $1.profit }
                
            return (current, prev)
        }.value
        
        withAnimation(.easeOut(duration: 0.2)) {
            self.currentAmount = result.0
            self.previousAmount = result.1
            self.isLoading = false
        }
    }
}

private struct EarningsBarRow: View {
    let label: String
    let amount: Decimal
    let maxValue: Double
    let color: Color

    var body: some View {
        let doubleAmount = Double(truncating: amount as NSNumber)
        // Avoid negative width
        let ratio = max(0, doubleAmount / maxValue)

        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(amount.formatted(.currency(code: "USD")))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 8)

                    // Filled bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(8, geo.size.width * CGFloat(ratio)),
                            height: 8
                        )
                        // Add a glow effect
                        .shadow(
                            color: color.opacity(0.3),
                            radius: 4,
                            x: 0,
                            y: 2
                        )
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    EarningsComparisonCard()
        .padding()
        .background(Color.black)
}
