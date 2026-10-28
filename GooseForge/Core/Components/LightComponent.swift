//
//  LightComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 13.08.2026.
//

import Foundation

struct LightComponent: Component {
    var light: Light
    var castsShadows: Bool = false
}
