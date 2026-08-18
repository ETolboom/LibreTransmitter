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
        let currentLifecycle = sensorLifecycle
        let currentIsPaired = isDeviceSelected
        DispatchQueue.main.async {
            self.sensorInfoObservable.sensorLifecycle = currentLifecycle
            self.sensorInfoObservable.isPaired = currentIsPaired
        }

        let newPersistableState = currentPersistableState
        if newPersistableState != lastPersistedState {
            lastPersistedState = newPersistableState
            let delegate = cgmManagerDelegate
            delegateQueue.async {
                delegate?.cgmManagerDidUpdateState(self)
            }
        }

        let shouldFire = LibreAlertCondition.currentlyFiring(for: currentLifecycle)

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
