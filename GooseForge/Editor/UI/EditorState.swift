//
//  EditorState.swift
//  GooseForge
//
//  Created by Igorchela on 19.10.2026.
//

import Observation

@Observable
class EditorState {
    let entityManager = EntityManager()
    var scene: SceneManager?
}
