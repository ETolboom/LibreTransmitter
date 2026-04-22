//
//  NotificationHelperOverride.swift
//  LibreTransmitter
//
//  Created by Bjørn Inge Berg on 16/01/2023.
//  Copyright © 2023 Mark Wilson. All rights reserved.
//

import Foundation
public enum NotificationHelperOverride {
    public static var shouldOverrideRequestCriticalPermissions : Bool {
        // if you want LibreTransmitter to override whether it shows the UI/banner for
        // the critical notification permissions flow, change this
        false
    }
}
