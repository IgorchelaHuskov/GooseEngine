//
//  AnimationComponent.swift
//  GooseForge
//
//  Created by Igorchela on 12.11.2026.
//

import Foundation

struct AnimationComponent: Component {
    var currentTime: Float = 0
    var speed: Float = 1
    var clip: AnimationClip
}
