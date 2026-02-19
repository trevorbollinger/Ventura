//
//  SessionTicker.swift
//  Ventura
//
//  Created by Auto-Agent on 2/5/26.
//

import Foundation
import Combine

/// A highly volatile object that updates every second.
/// Only specific sub-views should observe this. Main views (Dashboard, Drive) should NEVER observe this.
@MainActor
class SessionTicker: ObservableObject {
    @Published var state: SessionManager.ActiveSessionState = SessionManager.ActiveSessionState()
}
