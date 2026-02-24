//
//  CarPlayTemplateManager.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/19/26.
//

import Foundation
import CarPlay
import Combine
import SwiftData

@MainActor
class CarPlayTemplateManager: NSObject {
    private var interfaceController: CPInterfaceController
    private var cancellables = Set<AnyCancellable>()
    
    // Store reference to the main template we'll update live
    private var dashboardTemplate: CPInformationTemplate?
    
    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        super.init()
        
        setupSubscriptions()
    }
    
    func startGeneratingTemplates() {
        let template = generateDashboardTemplate()
        self.dashboardTemplate = template
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }
    
    private func generateDashboardTemplate() -> CPInformationTemplate {
        let isSessionActive = SessionManager.shared.activeSession != nil
        
        let title = isSessionActive ? "Active Session" : "Ventura"
        
        // Initial Items (will be updated dynamically)
        let earningsItem = CPInformationItem(title: "Net Profit", detail: "$0.00")
        let timeItem = CPInformationItem(title: "Time", detail: "00:00:00")
        let distanceItem = CPInformationItem(title: "Distance", detail: "0 mi")
        
        let template = CPInformationTemplate(title: title, layout: .leading, items: [earningsItem, timeItem, distanceItem], actions: [generateActionButton(isActive: isSessionActive)])
        
        return template
    }
    
    private func generateActionButton(isActive: Bool) -> CPTextButton {
        if isActive {
            return CPTextButton(title: "Stop Session", textStyle: .normal) { [weak self] _ in
                self?.presentStopConfirmation()
            }
        } else {
            return CPTextButton(title: "Start Session", textStyle: .normal) { _ in
                SessionManager.shared.startSession()
            }
        }
    }
    
    private func presentStopConfirmation() {
        let confirmAction = CPAlertAction(title: "End Session", style: .destructive) { [weak self] _ in
            SessionManager.shared.stopSession()
            self?.interfaceController.dismissTemplate(animated: true, completion: nil)
        }
        let cancelAction = CPAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.interfaceController.dismissTemplate(animated: true, completion: nil)
        }
        
        let alert = CPAlertTemplate(titleVariants: ["End this session?"], actions: [confirmAction, cancelAction])
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }
    
    private func setupSubscriptions() {
        // Track whether we had an active session to detect start/stop transitions
        var wasActive = SessionManager.shared.activeSession != nil
        
        // Observe the ticker for 1Hz updates — also detect session start/stop transitions
        SessionManager.shared.ticker.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                let isActive = SessionManager.shared.activeSession != nil
                
                // Detect session state transition (start/stop)
                if isActive != wasActive {
                    wasActive = isActive
                    let newTemplate = self.generateDashboardTemplate()
                    self.dashboardTemplate = newTemplate
                    self.interfaceController.setRootTemplate(newTemplate, animated: true, completion: nil)
                    
                    if isActive {
                        self.updateTemplateTick()
                    }
                } else if state.isSessionActive {
                    self.updateTemplateTick()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateTemplateTick() {
        guard let session = SessionManager.shared.activeSession,
              let settings = SessionManager.shared.cachedSettings,
              let template = dashboardTemplate else { return }
        
        let state = SessionManager.shared.currentSessionState(session: session, settings: settings)
        
        // Format Time
        let totalTimeInterval = SessionManager.shared.ticker.state.totalDuration
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        let timeString = formatter.string(from: totalTimeInterval) ?? "00:00:00"
        
        // Format Currency
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = state.currencyCode
        let earningsString = currencyFormatter.string(from: NSNumber(value: state.netProfit)) ?? "$0.00"
        
        let newItems = [
            CPInformationItem(title: "Net Profit", detail: earningsString),
            CPInformationItem(title: "Time", detail: timeString),
            CPInformationItem(title: "Distance", detail: String(state.totalDistance))
        ]
        
        template.items = newItems
    }
}
