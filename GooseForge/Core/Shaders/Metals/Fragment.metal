#include <metal_stdlib>
using namespace metal;

#import "../Headers/Lighting.h"
#import "../Headers/ShaderDefs.h"

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Params &params           [[buffer(ParamsBuffer)]],
                              constant Light *lights            [[buffer(LightBuffer)]],
                              constant Material &_material      [[buffer(MaterialBuffer)]],
                              texture2d<float> baseColorTexture [[texture(BaseColor)]],
                              texture2d<float> normalTexture    [[texture(NormalTexture)]],
                              texture2d<float> roughnessTexture [[texture(RoughnessTexture)]],
                              texture2d<float> metallicTexture  [[texture(MetallicTexture)]],
                              texture2d<float> aoTexture        [[texture(AOTexture)]],
                              texture2d<float> opacityTexture   [[texture(OpacityTexture)]],
                              depth2d<float> shadowTexture      [[texture(ShadowTexture)]])
{
    Material material = _material;
    float3 normal;
    constexpr sampler textureSampler(filter::linear, mip_filter::linear, max_anisotropy(8), address::repeat);
    if (!is_null_texture(baseColorTexture)) {
        material.baseColor = baseColorTexture.sample(textureSampler, in.uv * params.tiling).rgb;
    }
    
    if (!is_null_texture(opacityTexture)) {
        material.opacity = opacityTexture.sample(textureSampler, in.uv).r;
    }
    
    if (!is_null_texture(roughnessTexture)) {
        material.roughness = roughnessTexture.sample(textureSampler, in.uv * params.tiling).r;
    }
    
    if (is_null_texture(normalTexture)) { normal = in.worldNormal; } else {
        normal = normalTexture.sample(textureSampler, in.uv * params.tiling).rgb;
        normal = normal * 2 - 1;
        normal = float3x3(in.worldTangent, in.worldBitangent, in.worldNormal) * normal;
    }
    
    normal = normalize(normal);
    
    if (!is_null_texture(metallicTexture)) {
        material.metallic = metallicTexture.sample(textureSampler, in.uv * params.tiling).r;
    }
    
    if (!is_null_texture(aoTexture)) {
        material.ambientOcclusion = aoTexture.sample(textureSampler, in.uv * params.tiling).r;
    }
    
    float3 diffuseColor = computeDiffuse(lights, params, material, normal, in.worldPosition);
    float3 specularColor = computeSpecular(lights, params, material, normal, in.worldPosition);
    float shadow = calculateShadow(in.shadowPosition, shadowTexture);
    diffuseColor *= shadow;
    
    return float4(diffuseColor + specularColor, material.opacity);
}
