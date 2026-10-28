//
//  Mesh.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

struct Mesh {
    var vertexBuffers: [MTLBuffer]
    var submeshes: [Submesh]
}

extension Mesh {
    init(mdlMesh: MDLMesh, mtkMesh: MTKMesh, device: MTLDevice) {
        vertexBuffers = mtkMesh.vertexBuffers.map { $0.buffer }
        submeshes = zip(mdlMesh.submeshes!, mtkMesh.submeshes).map { mesh in
            Submesh(mdlSubmesh: mesh.0 as! MDLSubmesh, mtkSubmesh: mesh.1, device: device)
        }
    }
}
