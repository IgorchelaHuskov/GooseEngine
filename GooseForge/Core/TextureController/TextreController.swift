//
//  TextreController.swift
//  ECSRenderer
//
//  Created by Igorchela on 06.08.2026.
//

import MetalKit

enum TextureController {
    static var textures: [String: MTLTexture] = [:]
    
    static func loadTexture(texture: MDLTexture, name: String, device: MTLDevice, isSRGB: Bool) -> MTLTexture? {
        // 1. Проверяем кэш
        if let cached = textures[name] {
            return cached
        }
        
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.bottomLeft,
            .textureUsage: MTLTextureUsage.pixelFormatView.rawValue | MTLTextureUsage.shaderRead.rawValue,
            .generateMipmaps: true
            // .SRGB мы сюда НЕ пишем, он не работает для MDLTexture!
        ]
        
        var mtlTexture = try? textureLoader.newTexture(texture: texture, options: options)
        
        // 2. Принудительно делаем текстуру цветной (sRGB)
        print("Texture \(name) format before: \(mtlTexture?.pixelFormat.rawValue ?? 1)")
        if isSRGB, mtlTexture?.pixelFormat == .rgba8Unorm {
            mtlTexture = mtlTexture?.makeTextureView(pixelFormat: .rgba8Unorm_srgb)
            print("Texture \(name) converted to sRGB")
        }
        
        // 3. Кэшируем
        textures[name] = mtlTexture
        return mtlTexture
    }
    
    
    static func loadTexture(name: String, device: MTLDevice, isSRGB: Bool) -> MTLTexture? {
            let loader = MTKTextureLoader(device: device)
            
            // 1. Ищем файл по всему бандлу (включая синие папки)
            var fileURL: URL? = nil
            
            // Ищем в конкретной папке "ground", затем в корне
            let subdirectories: [String?] = ["grouns", nil]
            let extensions = ["png", "jpg", "jpeg"]
            
            for dir in subdirectories {
                for ext in extensions {
                    if let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: dir) {
                        fileURL = URL(fileURLWithPath: path)
                        break
                    }
                }
                if fileURL != nil { break }
            }
            
            // 2. Если нашли — грузим в память GPU
            if let url = fileURL {
                do {
                    let options: [MTKTextureLoader.Option: Any] = [
                        .textureUsage: MTLTextureUsage([.shaderRead]).rawValue,
                        .textureStorageMode: MTLStorageMode.private.rawValue,
                        .SRGB: isSRGB
                    ]
                    return try loader.newTexture(URL: url, options: options)
                } catch {
                    print("❌ Ошибка загрузки текстуры \(name) с диска: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // 3. Если файла нет на диске — возможно, он в Assets.xcassets
            // (Для macOS/iOS это можно попробовать загрузить через NSImage/UIImage)
            #if os(macOS)
            if let image = NSImage(named: name) {
                return try? loader.newTexture(cgImage: image.cgImage(forProposedRect: nil, context: nil, hints: nil)!, options: nil)
            }
            #endif
            
            print("❌ Файл \(name) не найден ни в папке ground, ни в корне бандла.")
            return nil
        }
    
    // load a cube texture
    static func loadCubeTexture(imageName: String) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: Renderer.device)
        // asset catalog loading
        if let texture = MDLTexture(cubeWithImagesNamed: [imageName]) {
            let options: [MTKTextureLoader.Option: Any] = [
                .origin: MTKTextureLoader.Origin.topLeft,
                .SRGB: false,
                .generateMipmaps: false
            ]
            return try? textureLoader.newTexture(
                texture: texture,
                options: options)
        }
        // bundle file loading
        let texture = try? textureLoader.newTexture(
            name: imageName,
            scaleFactor: Renderer.scaleFactor,
            bundle: .main)
        return texture
    }
}
