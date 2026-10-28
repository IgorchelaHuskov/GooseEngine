//
//  SceneLoader.swift
//  GooseEngine
//
//  Created by Igorchela on 12.10.2026.
//

import Foundation
import MetalKit
import simd

enum SceneLoaderError: Error, LocalizedError {
    case fileNotFound(String)
    case decodeFailed(Error)
    case unknownLightType(String)
    case unknownPrimitive(String)
    
    var errorDescription: String {
        switch self {
        case .fileNotFound(let n):     return "Scene file not found: \(n)"
        case .decodeFailed(let e):     return "Failed to parse scene: \(e.localizedDescription)"
        case .unknownLightType(let t): return "Unknown light type: \(t)"
        case .unknownPrimitive(let p): return "Unknown primitive: \(p)"
        }
    }
}

/// Результат загрузки — то, что SceneManager кладёт себе в свойства.
struct LoadedScene {
    let cameraEntity:       Entity
    let shadowCameraEntity: Entity?
    let sunEntities:        [Entity]
    let pointLightEntities: [Entity]
    let modelEntities:      [Entity]
}

enum SceneLoader {
    static func load(url: URL, into manager: EntityManager, device: MTLDevice) throws -> LoadedScene {
        // 1. Читаем файл
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw SceneLoaderError.fileNotFound(url.lastPathComponent) }
        
        // 2. Парсим JSON
        let file: SceneFile
        do { file = try JSONDecoder().decode(SceneFile.self, from: data) }
        catch { throw SceneLoaderError.decodeFailed(error) }
        
        // 3. Камера
        let cameraEntity = manager.createEntity()
        
        var fpCam = FPCameraComponent()
        let camEuler = file.camera.rotation.toFloat3()
        fpCam.pitch = camEuler.x    // orientationQuat инвертирует знак
        fpCam.yaw   = camEuler.y
        manager.addComponent(component: fpCam, to: cameraEntity)
        
        var cameraTransform = TransformComponent()
        cameraTransform.position = file.camera.position.toFloat3()
        cameraTransform.rotationQuat = fpCam.orientationQuat
        manager.addComponent(component: cameraTransform, to: cameraEntity)
        
        // 4. Свет
        var sunEntities:   [Entity] = []
        var pointEntities: [Entity] = []
        var hasShadowCaster = false
        
        for dto in file.lights ?? [] {
            guard let type = LightType(name: dto.type) else {
                throw SceneLoaderError.unknownLightType(dto.type)
            }
            
            var light = SceneLighting.buildDefaultLight()
            light.type       = type
            light.position   = dto.position.toFloat3()
            light.color      = dto.color.toFloat3()
            light.intensity  = dto.intensity
            light.radius     = dto.radius ?? 1.0
            if let att = dto.attenuation { light.attenuation = att.toFloat3() }
            
            let lightEntity = manager.createEntity()
            var lightComponen = LightComponent(light: light)
            lightComponen.castsShadows = dto.castsShadows
            manager.addComponent(component: lightComponen, to: lightEntity)
            
            if dto.castsShadows { hasShadowCaster = true }
            
            switch type {
            case Sun:   sunEntities.append(lightEntity)
            case Point: pointEntities.append(lightEntity)
            default:    break
            }
        }
        
        // 5. Shadow camera — только если есть хоть один кастер теней
        var shadowEntity: Entity? = nil
        if hasShadowCaster {
            let enntity = manager.createEntity()
            manager.addComponent(component: ShadowCameraComponent(), to: enntity)
            manager.addComponent(component: TransformComponent(),    to: enntity)
            shadowEntity = enntity
        }
        
        // 6. Модели
        var modelEntities: [Entity] = []
        for dto in file.entities ?? [] {
            let entities = try buildEnity(from: dto, manager: manager, device: device)
            modelEntities.append(entities)
        }
        
        return LoadedScene(cameraEntity: cameraEntity,
                           shadowCameraEntity: shadowEntity,
                           sunEntities: sunEntities,
                           pointLightEntities: pointEntities,
                           modelEntities: modelEntities)
    }
    
    // MARK: - Частное
    private static func buildEnity(from dto: EntityDTO, manager: EntityManager, device: MTLDevice) throws -> Entity {
        if dto.model == "unknown" {
            let emptyEntity = manager.createEntity()
            manager.addComponent(component: TransformComponent(), to: emptyEntity)
            return emptyEntity
        }
        
        let rootEntity: Entity
        if dto.model.hasPrefix("primitive:") {
            let name = String(dto.model.dropFirst("primitive:".count))
            guard let primitive = Primitive(name: name) else { throw SceneLoaderError.unknownPrimitive(name) }
            rootEntity = ModelLoader.loadPrimitive(type: primitive, named: name, manager: manager, device: device)
        } else {
            rootEntity = ModelLoader.loadModel(named: dto.model, manager: manager, device: device)
        }
        
        // 1. Трансформ — только на КОРЕНЬ.
        let proxy = manager.proxy(for: rootEntity)
        proxy.position = dto.position.toFloat3()
        proxy.eulerRotation = dto.rotation.toFloat3()
        proxy.scaleVec = dto.scale.toFloat3()
        
        // 2. Определяем, куда накатывать материал (Корень + Дети)
        let materialTargets = [rootEntity] + manager.children(of: rootEntity)
        
        // 3. Применяем материалы и текстуры к каждому таргету
        for entity in materialTargets {
            guard var material = manager.getComponent(for: entity) as MaterialComponent? else { continue }
            
            // Скалярные параметры (Tiling, Roughness и т.д.)
            if let tiling = dto.tiling { material.tiling = tiling }
            if let roughness = dto.roughness { material.material.roughness = roughness }
            if let metallic = dto.metallic { material.material.metallic = metallic }
            if let amOcclusion = dto.ambientOcclusion { material.material.ambientOcclusion = amOcclusion }
            if let opacity = dto.opacity {
                material.material.opacity = opacity
                material.isTransparent = (material.textures.opacity == nil && opacity < 1.0)
            }
            
            // Текстурные карты (слоты)
            if let tex = dto.baseColorTextureMap { material.setTexture(name: tex, type: BaseColor, device: device) }
            if let nor = dto.normalTextureMap { material.setTexture(name: nor, type: NormalTexture, device: device) }
            if let rough = dto.roughnessTextureMap { material.setTexture(name: rough, type: RoughnessTexture, device: device) }
            if let ao = dto.aoTextureMap { material.setTexture(name: ao, type: AOTexture, device: device) }
            
            // Внимание: у тебя в DTO опечатка "metalicTextreMap", я оставил как у тебя в коде
            if let metal = dto.metalicTextureMap { material.setTexture(name: metal, type: MetallicTexture, device: device) }
            if let opac = dto.opacityTextureMap { material.setTexture(name: opac, type: OpacityTexture, device: device) }
            
            manager.addComponent(component: material, to: entity)
        }
        
        return rootEntity
    }
}


// MARK: - Хелперы

private extension Array where Element == Float {
    func toFloat3() -> SIMD3<Float> {
        guard count >= 3 else { return .zero }
        return SIMD3(self[0], self[1], self[2])
    }
}

extension Primitive {
    init?(name: String) {
        switch name {
        case "plane":       self = .plane
        case "sphere":      self = .sphere
        case "icosahedron": self = .icosahedron
        case "cube":        self = .cube
        default:            return nil
        }
    }
}

extension LightType {
    init?(name: String) {
        switch name.lowercased() {
        case "sun":     self = Sun
        case "point":   self = Point
        case "spot":    self = Spot
        case "ambient": self = Ambient
        default:        return nil
        }
    }
}
