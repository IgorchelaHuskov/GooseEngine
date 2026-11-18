//
//  PlayerComponent.swift
//  GooseForge
//
//  Created by Igorchela on 17.11.2026.
//

import Foundation

enum PlayerState {
    case idle
    case running
    case action
}

struct PlayerComponent: Component {
    var speed: Float = 5.0
    var runMultiplier: Float = 1.5
    var state: PlayerState = .idle
    var canJump: Bool = true
}
