//
//  ModelLoader.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

enum Primitive {
    case plane, sphere, icosahedron, cube
}

class ModelLoader {
    
    static func loadModel(named name: String, manager: EntityManager, device: MTLDevice) -> Entity {
        guard let assetURL = Bundle.main.url(forResource: name, withExtension: nil) else {
            print("⚠️ Ошибка: Модель \(name) не найдена! Создана пустышка.")
            let emptyEntity = manager.createEntity()
            manager.addComponent(component: TransformComponent(), to: emptyEntity)
            return emptyEntity
        }
        
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: .defaultLayout, bufferAllocator: allocator)
        asset.loadTextures()
        
        var mtkMeshes: [MTKMesh] = []
        let mdlMeshes = asset.childObjects(of: MDLMesh.self) as? [MDLMesh] ?? []
        for mdlMesh in mdlMeshes {
            mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                    tangentAttributeNamed: MDLVertexAttributeTangent,
                                    bitangentAttributeNamed: MDLVertexAttributeBitangent)
            mtkMeshes.append(try! MTKMesh(mesh: mdlMesh, device: device))
        }
        
        // 1. Создаём корневую сущность без меша — чистый transform-контейнер
        let rootEntity = manager.createEntity()
        manager.addComponent(component: TransformComponent(), to: rootEntity)
        
        // 2. Каждый submesh — ребёнок корня
        for (mdlMesh, mtkMesh) in zip(mdlMeshes, mtkMeshes) {
            let mesh = Mesh(mdlMesh: mdlMesh, mtkMesh: mtkMesh, device: device)
            for index in 0..<mesh.submeshes.count {
                let partEntity = manager.createEntity()
                let partTextures = mesh.submeshes[index].textures
                let partMaterial = mesh.submeshes[index].material
                
                var materialComponent = MaterialComponent(textures: partTextures, material: partMaterial)
                materialComponent.isTransparent = mesh.submeshes[index].transparency
                
                manager.addComponent(component: MeshComponent(meshes: mesh, submeshesIndex: index, modelName: name), to: partEntity)
                manager.addComponent(component: materialComponent, to: partEntity)
                manager.addComponent(component: TransformComponent(), to: partEntity)
                manager.attach(child: partEntity, to: rootEntity)
            }
        }
        
        return rootEntity
    }
    
    static func loadPrimitive(type: Primitive, named name: String, manager: EntityManager, device: MTLDevice) -> Entity {
        let primitiveEntity = manager.createEntity()
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh: MDLMesh
        switch type {
        case .icosahedron:
            mdlMesh = MDLMesh(icosahedronWithExtent: [1, 1, 1],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
            
        case .plane:
            mdlMesh = MDLMesh(planeWithExtent: [10, 0, 10],
                              segments: [10, 10],
                              geometryType: .triangles,
                              allocator: allocator)
        case .sphere:
            mdlMesh = MDLMesh(sphereWithExtent: [1, 1, 1],
                              segments: [30, 30],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        case .cube:
            mdlMesh = MDLMesh(boxWithExtent: [1, 1, 1],
                              segments: [1, 1, 1],
                              inwardNormals: false,
                              geometryType: .triangles,
                              allocator: allocator)
        }
        
        mdlMesh.vertexDescriptor = MDLVertexDescriptor.defaultLayout
        mdlMesh.addTangentBasis(forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                tangentAttributeNamed: MDLVertexAttributeTangent,
                                bitangentAttributeNamed: MDLVertexAttributeBitangent)
        
        
        
        let mtkMesh = try! MTKMesh(mesh: mdlMesh, device: device)
        let mesh = Mesh(mdlMesh: mdlMesh, mtkMesh: mtkMesh, device: device)
        
        var defaultMaterial = Material()
        defaultMaterial.baseColor = float3(0.5, 0.5, 0.5)
        defaultMaterial.roughness = 0.5
        defaultMaterial.metallic = 0
        defaultMaterial.ambientOcclusion = 1.0
        defaultMaterial.opacity = 1.0 
        
        let textures = Submesh.Textures()
        
        manager.addComponent(component: MeshComponent(meshes: mesh, submeshesIndex: 0, modelName: "primitive:\(name)"), to: primitiveEntity)
        manager.addComponent(component: TransformComponent(), to: primitiveEntity)
        manager.addComponent(component: MaterialComponent(textures: textures, material: defaultMaterial), to: primitiveEntity)
        return primitiveEntity
    }
}
