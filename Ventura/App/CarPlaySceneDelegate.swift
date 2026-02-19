//
//  CarPlaySceneDelegate.swift
//  Ventura
//
//  Created by Trevor Bollinger on 2/19/26.
//

import CarPlay
import UIKit

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    var interfaceController: CPInterfaceController?
    var templateManager: CarPlayTemplateManager?

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        // Initialize the manager that will build and handle the UI
        templateManager = CarPlayTemplateManager(interfaceController: interfaceController)
        templateManager?.startGeneratingTemplates()
        
        print("🚗 CarPlay connected")
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        self.templateManager = nil
        
        print("🚗 CarPlay disconnected")
    }
}
