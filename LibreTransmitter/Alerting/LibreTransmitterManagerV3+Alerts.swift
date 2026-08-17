//
//  LibreTransmitterManagerV3+Alerts.swift
//  LibreTransmitter
//
//  Created by LoopKit Authors.
//  Copyright © 2026 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit

extension LibreTransmitterManagerV3 {
    /// Diffs the currently-firing lifecycle alert conditions against the previous
    /// evaluation and issues/retracts LoopKit Alerts for the delta.
    func evaluateAlerts() {
        let shouldFire = LibreAlertCondition.currentlyFiring(for: sensorLifecycle)

        guard shouldFire != firingAlertConditions else {
            return
        }

        let delegate = cgmManagerDelegate
        let managerIdentifier = Self.pluginIdentifier
        let newlyFiring = shouldFire.subtracting(firingAlertConditions)
        let noLongerFiring = firingAlertConditions.subtracting(shouldFire)

        delegateQueue.async {
            for condition in newlyFiring {
                delegate?.issueAlert(condition.alert(managerIdentifier: managerIdentifier))
            }
            for condition in noLongerFiring {
                delegate?.retractAlert(identifier: condition.identifier(managerIdentifier: managerIdentifier))
            }
        }

        firingAlertConditions = shouldFire
    }
}
