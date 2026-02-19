//
//  DateRangeHelper.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/3/26.
//

import Foundation

struct DateRangeHelper {
    static let shared = DateRangeHelper()
    private let calendar: Calendar
    
    init() {
        var cal = Calendar.current
        // Explicitly set first day of week to Monday
        cal.firstWeekday = 2 
        self.calendar = cal
    }
    
    // MARK: - Current Week Logic
    
    /// Returns the start (Monday 00:00) of the current week
    var startOfCurrentWeek: Date {
        let now = Date()
        return startOfWeek(for: now)
    }
    
    /// Returns the end (Sunday 23:59:59) of the current week
    var endOfCurrentWeek: Date {
        let start = startOfCurrentWeek
        return calendar.date(byAdding: .second, value: -1, to: calendar.date(byAdding: .weekOfYear, value: 1, to: start)!) ?? Date()
    }
    
    // MARK: - General Logic
    
    /// Returns the Monday 00:00 of the week containing the given date
    func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns the Sunday 23:59:59 of the week containing the given date
    func endOfWeek(for date: Date) -> Date {
        let start = startOfWeek(for: date)
        return calendar.date(byAdding: .second, value: -1, to: calendar.date(byAdding: .weekOfYear, value: 1, to: start)!) ?? date
    }
    
    /// Returns the start date for 'n' weeks ago.
    /// If n=1, it returns the start of the previous week.
    func startOfWeeksAgo(_ n: Int) -> Date {
        let start = startOfCurrentWeek
        return calendar.date(byAdding: .weekOfYear, value: -n, to: start) ?? start
    }
    
    /// Returns a full date interval for the "Last Week" (Previous Mon-Sun)
    var lastWeekInterval: DateInterval {
        let startOfLastWeek = startOfWeeksAgo(1)
        // End of last week is just before start of this week
        let endOfLastWeek = calendar.date(byAdding: .second, value: -1, to: startOfCurrentWeek)!
        return DateInterval(start: startOfLastWeek, end: endOfLastWeek)
    }
    
    // MARK: - Current Month Logic
    
    /// Returns the start (1st day 00:00) of the current month
    var startOfCurrentMonth: Date {
        let now = Date()
        return startOfMonth(for: now)
    }
    
    /// Returns the start of the month containing the given date
    func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns a full date interval for "Last Month"
    var lastMonthInterval: DateInterval {
        let startOfThisMonth = startOfCurrentMonth
        // Last month starts 1 month before this month
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        // End of last month is just before start of this month
        let endOfLastMonth = calendar.date(byAdding: .second, value: -1, to: startOfThisMonth)!
        return DateInterval(start: startOfLastMonth, end: endOfLastMonth)
    }
    
    // MARK: - Current Year Logic
    
    /// Returns the start (Jan 1 00:00) of the current year
    var startOfCurrentYear: Date {
        let now = Date()
        return startOfYear(for: now)
    }
    
    /// Returns the start of the year containing the given date
    func startOfYear(for date: Date) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? date
    }
    
    /// Returns a full date interval for "Last Year"
    var lastYearInterval: DateInterval {
        let startOfThisYear = startOfCurrentYear
        // Last year starts 1 year before this year
        let startOfLastYear = calendar.date(byAdding: .year, value: -1, to: startOfThisYear)!
        // End of last year is just before start of this year
        let endOfLastYear = calendar.date(byAdding: .second, value: -1, to: startOfThisYear)!
        return DateInterval(start: startOfLastYear, end: endOfLastYear)
    }
    
    // MARK: - Current Day Logic
    
    var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }
    
    var lastDayInterval: DateInterval {
        let startOfToday = self.startOfToday
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        let endOfYesterday = calendar.date(byAdding: .second, value: -1, to: startOfToday)!
        return DateInterval(start: startOfYesterday, end: endOfYesterday)
    }
    
    // MARK: - Analytics Filtering
    
    /// Returns the cutoff date for a standard analytics lookback.
    /// Logic: "5 Weeks" means we want to see the full data for the current week + the 4 full previous weeks.
    /// So we go back 4 weeks from the start of the current week.
    func startOfRollingWeekWindow(_ weeksBack: Int) -> Date {
        // weeksBack = 0 -> Start of this week
        // weeksBack = 1 -> Start of last week
        return startOfWeeksAgo(weeksBack)
    }
    
    func formatRange(_ start: Date, _ end: Date) -> String {
        let startStr = start.formatted(.dateTime.month().day())
        let endStr = end.formatted(.dateTime.month().day())
        return "\(startStr) - \(endStr)"
    }
}
