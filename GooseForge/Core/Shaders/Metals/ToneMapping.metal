//
//  ToneMapping.metal
//  GooseForge
//
//  Created by Igorchela on 16.11.2026.
//

#include <metal_stdlib>
using namespace metal;
#import "../Headers/Lighting.h"
#import "../Headers/ShaderDefs.h"

// Было: [[color(RenderTargetAlbedo)]]
// Стало: [[color(0)]]
fragment float4 fragment_tonemap(float4 currentColor [[color(0)]])
{
    float3 hdrColor = currentColor.rgb;
    
    // ВАЖНО: Т.к. твой экран (bgra8Unorm_srgb) не умеет хранить HDR (значения > 1.0),
    // ACES может сделать картинку слишком плоской.
    // Поставь экспозицию 1.0, чтобы просто вернуть цвета на место.
    float exposure = 0.3;
    hdrColor *= exposure;
    
    float3 ldrColor = acesToneMapping(hdrColor);
    
    // Легкая цветокоррекция в конце
    ldrColor = enhanceColor(ldrColor, 1.05, 1.1);
    
    return float4(ldrColor, 1.0);
}
