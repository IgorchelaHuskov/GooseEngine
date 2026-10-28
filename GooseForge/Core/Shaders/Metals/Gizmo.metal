//
//  Gizmo.metal
//  GooseForge
//
//  Created by Igorchela on 21.10.2026.
//

#include <metal_stdlib>
using namespace metal;
#import "../Headers/Common.h"



struct GizmoIn {
    float3 position [[attribute(0)]];
    float3 color    [[attribute(1)]];
};

struct GizmoOut {
    float4 position [[position]];
};

vertex GizmoOut vertex_gizmo(
    const GizmoIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(UniformsBuffer)]])
{
    GizmoOut out;
    // Исправлено: Добавлено умножение на uniforms.modelMatrix,
    // чтобы применились сдвиг, масштаб и поворот для конкретной оси гизмо
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(in.position, 1.0);
    return out;
}

fragment float4 fragment_gizmo(GizmoOut in [[stage_in]],
                               constant float4 &axisColor [[buffer(0)]])
{
    // Исправлено: Возвращаем переданный чистый цвет оси (красный, зеленый или синий)
    return axisColor;
}

