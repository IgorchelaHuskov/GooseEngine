//
//  SceneSaver.swift
//  GooseForge
//
//  Created by Igorchela on 25.10.2026.
//

import Foundation
import simd

enum SceneSaver {
    static func save(scene: SceneManager, manager: EntityManager, to url: URL) throws {
        // 1. Камера
        let camID = scene.activeCameraID!
        guard let camTransform = manager.getComponent(for: camID) as TransformComponent?,
              let fpCam = manager.getComponent(for: camID) as FPCameraComponent? else { return }
        let camDTO = CameraDTO(
            name: "player",
            position: [camTransform.position.x, camTransform.position.y, camTransform.position.z],
            rotation: [fpCam.pitch, fpCam.yaw, 0] // Возвращаем Euler для JSON
        )
        
        // 2. Свет
        var lightsDTO: [LightDTO] = []
        for (entity, lightComp) in manager.query(LightComponent.self) {
            guard let t = manager.getComponent(for: entity) as TransformComponent? else { continue }
            let l = lightComp.light
            
            // Определяем тип света строкой
            let typeStr: String
            switch l.type {
            case Sun: typeStr = "sun"
            case Point: typeStr = "point"
            default: typeStr = "sun"
            }
            
            lightsDTO.append(LightDTO(
                name: "light_\(entity)",
                type: typeStr,
                position: [t.position.x, t.position.y, t.position.z],
                color: [l.color.x, l.color.y, l.color.z],
                intensity: l.intensity,
                castsShadows: lightComp.castsShadows,
                radius: l.radius,
                attenuation: [l.attenuation.x, l.attenuation.y, l.attenuation.z]
            ))
        }
        
        // 3. Сущности (только корневые, у которых нет parent)
        var entitiesDTO: [EntityDTO] = []
        
        for (entity, transform) in manager.query(TransformComponent.self) {
            // 1. Пропускаем детей
            if transform.parent != nil { continue }
            
            // 2. Пропускаем камеру игрока
            if entity == scene.activeCameraID { continue }
            
            // 3. Пропускаем камеру теней 
            if entity == scene.shadowCameraID { continue }
            
            // 4. Пропускаем пустой икосаэдр для точечных светов
            if entity == scene.icosahedron { continue }
            
            // 5. Пропускаем свет (он сохраняется отдельно)
            if manager.getComponent(for: entity) as LightComponent? != nil { continue }
            
            // Ищем MeshComponent (либо на самой сущности, либо на её детях)
            var modelName = "unknown"
            var material: MaterialComponent?
            
            if let meshComp = manager.getComponent(for: entity) as MeshComponent? {
                modelName = meshComp.modelName
                material = manager.getComponent(for: entity) as MaterialComponent?
            } else {
                // Если это модель (USDZ), меш лежит на первом ребёнке
                let children = manager.children(of: entity)
                if let firstChild = children.first,
                   let childMesh = manager.getComponent(for: firstChild) as MeshComponent? {
                    modelName = childMesh.modelName
                    material = manager.getComponent(for: firstChild) as MaterialComponent?
                }
            }
            if modelName == "unknown" { continue }
            var dto = EntityDTO(name: "Entity_\(entity)", model: modelName)
            dto.position = [transform.position.x, transform.position.y, transform.position.z]
            
            // Конвертируем Quaternion обратно в Euler для JSON
            let euler = eulerYXZ(from: transform.rotationQuat)
            dto.rotation = [euler.x, euler.y, euler.z]
            dto.scale = [transform.scaleVec.x, transform.scaleVec.y, transform.scaleVec.z]
            
            if modelName.hasPrefix("primitive:") {
                if let mat = material {
                    dto.tiling = mat.tiling
                    dto.roughness = mat.material.roughness
                    dto.metallic = mat.material.metallic
                    dto.ambientOcclusion = mat.material.ambientOcclusion
                    dto.opacity = mat.material.opacity
                    
                    dto.baseColorTextureMap = mat.baseColorTextureName
                    dto.normalTextureMap = mat.normalTextureName
                    dto.roughnessTextureMap = mat.roughnessTextureName
                    dto.aoTextureMap = mat.aoTextureName
                    dto.metalicTextureMap = mat.metalicTextreName
                    dto.opacityTextureMap = mat.opacityTextureName
                }
            }
            
            entitiesDTO.append(dto)
        }
        
        // 4. Собираем всё вместе
        let sceneFile = SceneFile(
            version: 1,
            camera: camDTO,
            lights: lightsDTO,
            entities: entitiesDTO
        )
        
        // 5. Записываем в файл
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sceneFile)
        try data.write(to: url)
        print("✅ Scene saved to \(url.path)")
    }
}

