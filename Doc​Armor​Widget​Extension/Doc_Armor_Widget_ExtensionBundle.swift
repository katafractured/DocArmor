//
//  Doc_Armor_Widget_ExtensionBundle.swift
//  Doc​Armor​Widget​Extension
//
//  Created by Christian Flores on 3/24/26.
//

import WidgetKit
import SwiftUI

@main
struct Doc_Armor_Widget_ExtensionBundle: WidgetBundle {
    var body: some Widget {
        DocArmorQuickLaunchWidget()
        DocArmorReadinessWidget()
    }
}
