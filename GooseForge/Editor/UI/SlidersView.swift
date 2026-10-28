//
//  SlidersView.swift
//  GooseEngine
//
//  Created by Igorchela on 10.10.2026.
//

import SwiftUI

public struct SlidersView: View {
    @Bindable public var options: Options
    
    public init(options: Options) {
        self.options = options
    }
    
    public var body: some View {
        VStack {
            Text("Texture is regenerated after each slider is moved")
                .font(.caption2)
                .fontWeight(.bold)
            HStack {
                Text("Мутность атмосферы:")
                Slider(value: $options.turbidity) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.turbidity, specifier: "%.2f")")
            }
            HStack {
                Text("Высота солнца:")
                Slider(value: $options.sunElevation) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.sunElevation, specifier: "%.2f")")
            }
            HStack {
                Text("Рассеивание отмосферы:")
                Slider(value: $options.upperAtmosphereScattering) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.upperAtmosphereScattering, specifier: "%.2f")")
            }
            HStack {
                Text("Отражательная способность земли:")
                Slider(value: $options.groundAlbedo, in: -10...10) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.groundAlbedo, specifier: "%.2f")")
            }
            
            HStack {
                Text("Азимут солнца:")
                Slider(value: $options.sunAzimuth, in: 0...7) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.sunAzimuth, specifier: "%.2f")")
            }
            
            HStack {
                Text("Гамма-коррекция:")
                Slider(value: $options.gamma, in: 0...10) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.gamma, specifier: "%.2f")")
            }
            
            HStack {
                Text("Экспозиция:")
                Slider(value: $options.exposure, in: -10...10) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.exposure, specifier: "%.2f")")
            }
            
            HStack {
                Text("Контраст:")
                Slider(value: $options.contrast, in: -10...10) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.contrast, specifier: "%.2f")")
            }
            
            HStack {
                Text("Насыщенность:")
                Slider(value: $options.saturation, in: -10...10) { editing in
                    if !editing {
                        options.shouldGenerateSkybox = true
                    }
                }
                Text("\(options.saturation, specifier: "%.2f")")
            }
            
        }
        .font(.caption)
        .padding()
    }
}

