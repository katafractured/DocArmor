import WidgetKit
import SwiftUI

/// Widget bundle entry point.
///
/// HOW TO SET UP THE WIDGET EXTENSION TARGET IN XCODE:
/// 1. File → New → Target → Widget Extension, name it "DocArmorWidgetExtension"
/// 2. Add this file + QuickLaunchWidget.swift + VaultSnapshotStore.swift + AppGroup.swift to that target
/// 3. Add the App Group entitlement (`AppGroup.identifier`) to both targets
/// 4. The @main attribute belongs only in the widget extension target — do NOT
///    include this file in the main DocArmor app target.
///
/// This file is kept here for reference / source organization.
struct DocArmorWidgetBundle: WidgetBundle {
    var body: some Widget {
        QuickLaunchWidget()
        ReadinessWidget()
    }
}
