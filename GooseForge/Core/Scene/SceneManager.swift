//
//  SceneManager.swift
//  ECSRenderer
//
//  Created by Igorchela on 07.08.2026.


import MetalKit

@Observable
class SceneManager {
    var systems: [System] = []
    
    var lightsBuffer:   MTLBuffer!
    var sunBuffer:      MTLBuffer!
    var pointBuffer:    MTLBuffer!
    
    var activeCameraID: Entity!
    var shadowCameraID: Entity?
    var icosahedron:    Entity!
    var selectedEntity: Entity?
    
    var allLights:      [Light] = []
    var sunLights:      [Light] = []
    var pointLights:    [Light] = []
    
    //let sceneLight  = SceneLighting()
    
    var size: CGSize = .zero
    
    var skyBox: Skybox?
    
    var manager: EntityManager
    
    init(manager: EntityManager, device: MTLDevice, options: Options, sceneURL: URL?) {
        skyBox = Skybox(textureName: "sky")
        self.manager = manager
        if let url = sceneURL {
            do {
                let loader = try SceneLoader.load(url: url, into: manager, device: device)
                self.activeCameraID = loader.cameraEntity
                self.shadowCameraID = loader.shadowCameraEntity
                self.icosahedron = loader.pointLightEntities.isEmpty
                    ? manager.createEntity()
                    : ModelLoader.loadPrimitive(type: .icosahedron, named: "icosahedron", manager: manager, device: device)
            } catch { print("⚠️ Scene load failed: \(error)") }
        }
        systems = [InputSystem(), FPCameraSystem(), ShadowCameraSystem()]
        rebuildLightBuffers(manager: manager, device: device)
    }
    
    func duplicateSelectedEntity() {
        guard let selected = selectedEntity else { return }
        
        let newEntity = manager.duplicate(entity: selected)
        
        // Сдвигаем копию, чтобы она не перекрывала оригинал
        if var transform = manager.getComponent(for: newEntity) as TransformComponent? {
            transform.position.x += 1.0
            manager.addComponent(component: transform, to: newEntity)
        }
        
        // Выделяем новую копию
        selectedEntity = newEntity
        
        // Если это был свет — обновляем буферы, иначе свет визуально не сдвинется
      // if manager.getComponent(for: newEntity) is LightComponent? {
      //     rebuildLightBuffers(manager: manager, device: Renderer.device)
      // }
        
    }
    
    func deleteSelectedEntity() {
        guard let selected = selectedEntity else { return }
        
        // Проверяем, был ли это свет (чтобы обновить буферы)
        let wasLight = manager.getComponent(for: selected) as LightComponent? != nil
        
        // Удаляем сущность и всех её детей
        manager.removeEntity(selected)
        
        // Сбрасываем выделение
        selectedEntity = nil
        
        // Если удалили свет — пересобираем буфер освещения
        if wasLight {
            rebuildLightBuffers(manager: manager, device: Renderer.device)
        }
        
        print("🔴 Deleted entity \(selected)")
    }
    
    
    // Общий сборщик освещения
    func collectLights(manager: EntityManager) {
        var suns:   [Light] = []
        var points: [Light] = []
        for (_, lightComp) in manager.query(LightComponent.self) {
            switch lightComp.light.type {
            case Point:  points.append(lightComp.light)
            default:     suns.append(lightComp.light)
            }
        }
        sunLights   = suns
        pointLights = points
        allLights   = suns + points
    }

    // Пересборка буферов
    func rebuildLightBuffers(manager: EntityManager, device: MTLDevice) {
        collectLights(manager: manager)
        sunBuffer    = createLightMTLBuffer(lights: sunLights,   device: device)
        pointBuffer  = createLightMTLBuffer(lights: pointLights, device: device)
        lightsBuffer = createLightMTLBuffer(lights: allLights,  device: device)
    }

    private func createLightMTLBuffer(lights: [Light], device: MTLDevice) -> MTLBuffer {
        var safeLights = lights.isEmpty ? [Light()] : lights
        let length = MemoryLayout<Light>.stride * safeLights.count
        guard let buffer = device.makeBuffer(bytes: &safeLights,
                                             length: length,
                                             options: .storageModeShared) else {
            fatalError("Failed to create light buffer")
        }
        buffer.label = "Light Buffer (\(lights.count))"
        return buffer
    }
    
    func update(manager: EntityManager, deltaTime: Float)  {
        for system in systems {
            system.update(manager: manager, scene: self, deltaTime: deltaTime)
        }
    }
    
    func update(manager: EntityManager, size: CGSize) {
        self.size = size
        for system in systems {
            system.update(manager: manager, scene: self, size: size)
        }
    }
}
 
extension SceneManager {
    // Добавление примитива (Куб, Сфера и т.д.)
    func addPrimitive(_ primitive: Primitive) {
        let name = String(describing: primitive)
        let newEntity = ModelLoader.loadPrimitive(type: primitive, named: name, manager: manager, device: Renderer.device)
        
        // Ставим перед камерой
        positionInFrontOfCamera(entity: newEntity)
        
        // Выделяем его
        selectedEntity = newEntity
    }
    
    // Добавление USDZ модели
    func addModel(named modelName: String) {
        let newEntity = ModelLoader.loadModel(named: modelName, manager: manager, device: Renderer.device)
        positionInFrontOfCamera(entity: newEntity)
        selectedEntity = newEntity
    }
    
    // Вспомогательная функция: ставит объект в 5 метрах перед камерой
    private func positionInFrontOfCamera(entity: Entity) {
        guard let camTransform = manager.getComponent(for: activeCameraID) as TransformComponent? else { return }
        
        // Вектор взгляда камеры (вперёд)
        let forward = camTransform.rotationQuat.act([0, 0, 1])
        let spawnPos = camTransform.position + forward * 5.0
        
        if var transform = manager.getComponent(for: entity) as TransformComponent? {
            transform.position = spawnPos
            manager.addComponent(component: transform, to: entity)
        }
    }
    
    /// Возвращает список всех .usdz моделей в бандле
    func availableModels() -> [String] {
        // Ищем файлы с расширением usdz во всех папках бандла
        let paths = Bundle.main.paths(forResourcesOfType: "usdz", inDirectory: nil)
        
        // Извлекаем только имя файла (например, "house1.usdz") и сортируем
        let names = paths.compactMap { URL(fileURLWithPath: $0).lastPathComponent }
        return names.sorted()
    }
}

extension SceneManager {
    /// Возвращает список имен всех текстур в бандле (без расширения)
    func availableTextures() -> [String] {
        let extensions = ["png", "jpg", "jpeg"]
        var textureNames: Set<String> = []
        
        for ext in extensions {
            let paths = Bundle.main.paths(forResourcesOfType: ext, inDirectory: nil)
            for path in paths {
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                textureNames.insert(name)
            }
        }
        return Array(textureNames).sorted()
    }
    
    func applyTexture(name: String, type: TextureIndices) {
        guard let selected = selectedEntity else { return }
        let materialTargets = [selected] + manager.children(of: selected)
        
        for entity in materialTargets {
            guard var material = manager.getComponent(for: entity) as MaterialComponent? else { continue }
            
            if name.isEmpty {
                // Если передали пустую строку — удаляем текстуру (None)
                switch type {
                case BaseColor: material.textures.baseColor = nil; material.baseColorTextureName = nil
                case NormalTexture: material.textures.normal = nil; material.normalTextureName = nil
                case RoughnessTexture: material.textures.roughness = nil; material.roughnessTextureName = nil
                case MetallicTexture: material.textures.metallic = nil; material.metalicTextreName = nil
                case AOTexture: material.textures.ambientOcclusion = nil; material.aoTextureName = nil
                case OpacityTexture: material.textures.opacity = nil; material.opacityTextureName = nil
                default: break
                }
            } else {
                // Если передали имя — загружаем
                material.setTexture(name: name, type: type, device: Renderer.device)
            }
            
            manager.addComponent(component: material, to: entity)
        }
    }
}


