//
//  IBL.metal
//  GooseEngine
//
//  Created by Igorchela on 09.10.2026.
//

#include <metal_stdlib>
using namespace metal;


#import "../Headers/Lighting.h"
#import "../Headers/ShaderDefs.h"
#import "../Headers/SkyTransform.h"

// ============================================================
//  FULL-SCREEN QUAD
// ============================================================

struct QuadOut {
    float4 position [[position]];
    float2 uv;
};

constant float2 quadVertices[6] = {
    float2(-1,  1),
    float2( 1, -1),
    float2(-1, -1),
    float2(-1,  1),
    float2( 1,  1),
    float2( 1, -1)
};

vertex QuadOut vertex_quad(uint vertexID [[vertex_id]]) {
    float2 p = quadVertices[vertexID];
    QuadOut out;
    out.position = float4(p, 0, 1);
    out.uv = float2(p.x * 0.5 + 0.5, 0.5 - p.y * 0.5);
    return out;
}


// ============================================================
//  G-BUFFER PASS
// ============================================================

struct GBufferOut {
    float4 albedo   [[color(RenderTargetAlbedo)]];
    float4 normal   [[color(RenderTargetNormal)]];
    float4 position [[color(RenderTargetPosition)]];
    float4 aux      [[color(RenderTargetAux)]];
    uint   entityID [[color(RenderTargetEntityID)]];
};

fragment GBufferOut fragment_gBuffer(
    VertexOut in [[stage_in]],
    constant Params   &params          [[buffer(ParamsBuffer)]],
    constant Material &_material       [[buffer(MaterialBuffer)]],
    constant uint     &entityID        [[buffer(EntityIDBuffer)]],
    texture2d<float>  baseColorTexture [[texture(BaseColor)]],
    texture2d<float>  normalTexture    [[texture(NormalTexture)]],
    texture2d<float>  roughnessTexture [[texture(RoughnessTexture)]],
    texture2d<float>  metallicTexture  [[texture(MetallicTexture)]],
    texture2d<float>  aoTexture        [[texture(AOTexture)]],
    texture2d<float>  opacityTexture   [[texture(OpacityTexture)]],
    depth2d<float>    shadowTexture    [[texture(ShadowTexture)]])
{
    GBufferOut out;
    Material material = _material;
    constexpr sampler textureSampler(filter::linear, mip_filter::linear, address::repeat);
    float2 uv = in.uv * params.tiling;
    
    // 1. Проверяем основную текстуру
    if (!is_null_texture(baseColorTexture)) {
        float4 color = baseColorTexture.sample(textureSampler, in.uv * params.tiling);
        material.baseColor = color.rgb;
        if (params.alphaTesting && color.a < 0.1) { discard_fragment(); }
        
    } else {
        bool isDefaultGrey = all(abs(material.baseColor - float3(0.5, 0.5, 0.5)) < 0.01);
        
        if (isDefaultGrey) {
            // Если текстуры нет и цвет дефолтный — рисуем шахматку
            uint checks = 8;
            float2 checkerUV = fract(uv * checks * 0.5) - 0.5;
            float checkerValue = step(checkerUV.x * checkerUV.y, 0.0);
            material.baseColor = mix(float3(1.0, 0.0, 1.0), float3(0.0), checkerValue);
        }
    }
    
    if (params.alphaBlending) {
        if (!is_null_texture(opacityTexture)) {
            material.opacity = opacityTexture.sample(textureSampler, in.uv).r;
        }
    }
    
    if (!is_null_texture(roughnessTexture)) {
        material.roughness = roughnessTexture.sample(textureSampler, uv).r;
    }
    
    if (!is_null_texture(metallicTexture)) {
        material.metallic = metallicTexture.sample(textureSampler, uv).r;
    }
    
    if (!is_null_texture(aoTexture)) {
        material.ambientOcclusion = aoTexture.sample(textureSampler, uv).r;
    }
    
    float3 normal;
    if (is_null_texture(normalTexture)) {
        normal = in.worldNormal;
    } else {
        normal = normalTexture.sample(textureSampler, uv).rgb;
        normal = normal * 2 - 1;
        normal = float3x3(in.worldTangent, in.worldBitangent, in.worldNormal) * normal;
    }
    normal = normalize(normal);
    
    float shadow = params.shadowsEnabled
    ? calculateShadow(in.shadowPosition, shadowTexture)
    : 1.0;
    
    float selected = 0.0;
    if (params.selectedEntityID != 0 && entityID == params.selectedEntityID) {
        selected = 1.0;
    }
    
    out.albedo   = float4(material.baseColor, material.ambientOcclusion);
    out.normal   = float4(normal, material.metallic);
    out.position = float4(in.worldPosition, material.roughness);
    out.aux      = float4(shadow, 0, 0, selected);
    out.entityID = entityID;
    
    return out;
}


// ============================================================
//  IBL — framebuffer fetch
// ============================================================

fragment float4 fragment_IBL(
    constant Params   &params   [[buffer(ParamsBuffer)]],
    float4 gAlbedo   [[color(RenderTargetAlbedo)]],
    float4 gNormal   [[color(RenderTargetNormal)]],
    float4 gPosition [[color(RenderTargetPosition)]],
    float4 gAux      [[color(RenderTargetAux)]],
    texturecube<float> skybox        [[texture(SkyboxTexture)]],
    texturecube<float> skyboxDiffuse [[texture(SkyboxDiffuseTexture)]],
    texture2d<float>   brdfLut       [[texture(BRDFLutTexture)]])
{
    
    // 1. Извлекаем данные из G-Буфера
    float3 baseColor        = gAlbedo.rgb;
    float3 normal           = normalize(gNormal.rgb);
    float3 worldPos         = gPosition.rgb;
    float roughness         = gPosition.a;
    float metallic          = gNormal.a;
    float ambientOcclusion  = gAlbedo.a;
    
    constexpr sampler textureSampler(filter::linear, mip_filter::linear, address::repeat);
    
    float4 color = float4(baseColor, 1);
    
    float3 viewDirection = worldPos.xyz - params.cameraPosition;
    viewDirection = normalize(viewDirection);
    float3 textureCoordinates =
    reflect(viewDirection, normal);
    
    float4 diffuse = skyboxDiffuse.sample(textureSampler, normal);
    
    diffuse = mix(pow(diffuse, 0.2), diffuse, metallic);
    color = diffuse * float4(baseColor, 1);
    
    constexpr sampler s(filter::linear, mip_filter::linear);
    float3 prefilteredColor = skybox.sample(s, textureCoordinates, level(roughness * 10)).rgb;
    float nDotV = saturate(dot(normal, -viewDirection));
    float2 envBRDF = brdfLut.sample(s, float2(roughness, nDotV)).rg;
    float3 f0 = mix(0.04, baseColor.rgb, metallic);
    float3 specularIBL = f0 * envBRDF.r + envBRDF.g;
    
    float3 specular = prefilteredColor * specularIBL;
    color += float4(specular, 1);
    color *= ambientOcclusion;
    
    float selected = gAux.a;

    if (selected > 0.0) {
        float3 N = normalize(gNormal.rgb);
        float3 V = normalize(params.cameraPosition - gPosition.rgb);
        float fresnel = pow(1.0 - saturate(dot(N, V)), 2.0);   // 0 в центре, 1 на краях
        color.rgb += float3(1.0, 0.55, 0.1) * fresnel * 1.5 * selected;
    }
    
    return color;
}


// ============================================================
//  POINT LIGHTS — framebuffer fetch
// ============================================================

struct PointLightIn {
    float4 position [[attribute(Position)]];
};

struct PointLightOut {
    float4 position [[position]];
    uint   instanceId [[flat]];
};

vertex PointLightOut vertex_pointLight(
    PointLightIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(UniformsBuffer)]],
    constant Light    *lights   [[buffer(LightBuffer)]],
    uint instanceId [[instance_id]])
{
    float4 lightPosition = float4(lights[instanceId].position, 0);
    float4 position = uniforms.projectionMatrix * uniforms.viewMatrix * (in.position + lightPosition);
    PointLightOut out {
        .position   = position,
        .instanceId = instanceId
    };
    return out;
}

fragment float4 fragment_pointLight(
    PointLightOut in [[stage_in]],
    constant Params &params [[buffer(ParamsBuffer)]],
    constant Light  *lights [[buffer(LightBuffer)]],
    float4 gAlbedo   [[color(RenderTargetAlbedo)]],
    float4 gNormal   [[color(RenderTargetNormal)]],
    float4 gPosition [[color(RenderTargetPosition)]])
{
    Material material {
        .baseColor = gAlbedo.rgb,
        .roughness = gPosition.a,
        .metallic  = gNormal.a
    };

    float3 normal        = gNormal.rgb;
    float3 worldPosition = gPosition.rgb;

    Light light = lights[in.instanceId];
    float3 color = calculatePointDiffuse(light, normal, material, worldPosition);
    color *= 0.5;
    return float4(color, 1);
}

fragment float4 fragment_deferredSun(
    constant Params  &params [[buffer(ParamsBuffer)]],
    constant Light   *lights [[buffer(LightBuffer)]],
    float4 gAlbedo   [[color(RenderTargetAlbedo)]],
    float4 gNormal   [[color(RenderTargetNormal)]],
    float4 gPosition [[color(RenderTargetPosition)]],
    float4 gAux      [[color(RenderTargetAux)]])
{
    Material material {
        .baseColor        = gAlbedo.rgb,
        .ambientOcclusion = gAlbedo.a,
        .roughness        = gPosition.a,
        .metallic         = gNormal.a
    };

    float3 normal        = normalize(gNormal.rgb);
    float3 worldPosition = gPosition.rgb;
    float  shadow        = gAux.r;

    float3 diffuse  = 0;
    float3 specular = 0;
    float3 V = normalize(params.cameraPosition - worldPosition);

    for (uint i = 0; i < params.lightCount; ++i) {
        Light L = lights[i];
        if (L.type != Sun) { continue; }

        diffuse  += calculateSunDiffuse(L, normal, params, material);
        specular += calculateSunSpecular(L, material, V, normal);
    }

    float3 color = (diffuse + specular) * shadow;
    return float4(color, 1);
}
