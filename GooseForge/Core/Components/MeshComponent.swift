//
//  MeshComponent.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import Foundation

struct MeshComponent: Component {
    var meshes: Mesh
    let submeshesIndex: Int
    let modelName: String
}
