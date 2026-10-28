//
//  System.swift
//  ECSRenderer
//
//  Created by Igorchela on 11.08.2026.
//

import Foundation

protocol System {
    func update(manager: EntityManager, scene: SceneManager, size: CGSize)
    func update(manager: EntityManager, scene: SceneManager, deltaTime: Float)
}
