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
        
        // Loading the Skeleton
        let skeletons = asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton] ?? []
        if let skeleton = Skeleton(mdlSkeleton: skeletons.first) {
            let skeletonComponent = SkeletonComponent(parentIndices: skeleton.parentIndices,
                                                      jointPaths: skeleton.jointPaths,
                                                      bindTransforms: skeleton.bindTransforms,
                                                      restTransforms: skeleton.restTransforms,
                                                      currentPose: skeleton.currentPose)
            
            manager.addComponent(component: skeletonComponent, to: rootEntity)
        }
        
        // Loading the Animation
        let assetAnimations = asset.animations.objects.compactMap { $0 as? MDLPackedJointAnimation }
        if !assetAnimations.isEmpty {
            var clipsDict: [String:AnimationClip] = [:]
            var firstClipName = ""
            
            for(index, animation) in assetAnimations.enumerated() {
                let animationClip = AnimationClip(animation: animation)
                let clipName = animationClip.name.isEmpty ? "Clip_\(index)" : animationClip.name
                clipsDict[clipName] = animationClip
                if index == 0 { firstClipName = clipName }
            }
            
            var animationComponent = AnimationComponent()
            animationComponent.clips = clipsDict
            animationComponent.currentClipName = firstClipName
            manager.addComponent(component: animationComponent, to: rootEntity)
            print("✅ Загружено анимаций: \(clipsDict.count) -> \(clipsDict.keys)")
        }
        
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
        
                // Loading the Skinning Data
                let animationBindComponent = mdlMesh.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent
                let skeletonComp = manager.getComponent(for: rootEntity) as SkeletonComponent?
                if let skin = Skin(animationBindComponent: animationBindComponent, skeleton: skeletonComp) {
                    let skinComponent = SkinComponent(skinToSkeletonMap: skin.skinToSkeletonMap,
                                                      jointMatrixPaletteBuffer: skin.jointMatrixPaletteBuffer)
                    
                    manager.addComponent(component: skinComponent, to: partEntity)
                }
                
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
            mdlMesh = MDLMesh(planeWithExtent: [1, 0, 1],
                              segments: [4, 4],
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
        defaultMaterial.roughness = 1
        defaultMaterial.metallic = 0.0
        defaultMaterial.ambientOcclusion = 1.0
        defaultMaterial.opacity = 1.0 
        
        let textures = Submesh.Textures()
        
        manager.addComponent(component: MeshComponent(meshes: mesh, submeshesIndex: 0, modelName: "primitive:\(name)"), to: primitiveEntity)
        manager.addComponent(component: TransformComponent(), to: primitiveEntity)
        manager.addComponent(component: MaterialComponent(textures: textures, material: defaultMaterial), to: primitiveEntity)
        return primitiveEntity
    }
}

extension ModelLoader {
    /// Загружает анимацию из отдельного файла и сохраняет её под именем самого файла (без .usdz)
    static func loadAnimation(named fileName: String, for entity: Entity, manager: EntityManager) {
        guard let assetURL = Bundle.main.url(forResource: fileName, withExtension: nil) else {
            print("⚠️ Файл анимации \(fileName) не найдена!")
            return
        }
        
        let asset = MDLAsset(url: assetURL)
        let animations = asset.animations.objects.compactMap { $0 as? MDLPackedJointAnimation }
        
        guard !animations.isEmpty else {
            print("⚠️ В файле \(fileName) нет анимаций!")
            return
        }
        
        // Берем AnimationComponent персонажа (или создаем новый, если модель загружена без базовой анимации)
        var animComponent = (manager.getComponent(for: entity) as AnimationComponent?) ?? AnimationComponent()
        
        // Автоматически находим индекс корневой кости (таза), если еще не найден
        if let skelComp = manager.getComponent(for: entity) as SkeletonComponent?,
           let hipsIdx = skelComp.jointPaths.firstIndex(where: {
               $0.localizedCaseInsensitiveContains("hips") || $0.localizedCaseInsensitiveContains("pelvis")
           }) {
            animComponent.rootJointIndex = hipsIdx
        }
        
        // Отрезаем расширение файла: "PlayerJump.usdz" -> "PlayerJump"
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        
        for (index, anim) in animations.enumerated() {
            let clip = AnimationClip(animation: anim)
            // Если в файле 1 анимация — называем её точно как файл ("PlayerJump").
            // Если в файле вдруг зашито несколько анимаций — добавляем индекс ("Combo_0", "Combo_1").
            let clipName = animations.count == 1 ? baseName : "\(baseName)_\(index)"
            
            animComponent.clips[clipName] = clip
            
            // Если у персонажа еще не было активной анимации, ставим эту первой
            if animComponent.currentClipName.isEmpty {
                animComponent.currentClipName = clipName
            }
            
            print("✅ Добавлена анимация: '\(clipName)' (из \(fileName))")
        }
        
        manager.addComponent(component: animComponent, to: entity)
    }
}

