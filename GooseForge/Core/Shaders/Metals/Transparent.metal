//
//  Transparent.metal
//  GooseEngine
//
//  Created by Igorchela on 09.10.2026.
//

#include <metal_stdlib>
using namespace metal;


#import "../Headers/Lighting.h"
#import "../Headers/ShaderDefs.h"
#import "../Headers/SkyTransform.h"

fragment float4 fragment_transparent(
    VertexOut in [[stage_in]],
    constant Params   &params         [[buffer(ParamsBuffer)]],
    constant Light    *lights         [[buffer(LightBuffer)]],
    constant Material &_material      [[buffer(MaterialBuffer)]],
    texture2d<float> baseColorTexture [[texture(BaseColor)]],
    texture2d<float> normalTexture    [[texture(NormalTexture)]],
    texture2d<float> roughnessTexture [[texture(RoughnessTexture)]],
    texture2d<float> metallicTexture  [[texture(MetallicTexture)]],
    texture2d<float> aoTexture        [[texture(AOTexture)]],
    texture2d<float> opacityTexture   [[texture(OpacityTexture)]],
    depth2d<float>   shadowTexture    [[texture(ShadowTexture)]],
    texturecube<float> skybox         [[texture(SkyboxTexture)]],
    texturecube<float> skyboxDiffuse  [[texture(SkyboxDiffuseTexture)]],
    texture2d<float>   brdfLut        [[texture(BRDFLutTexture)]])
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

    // === Direct ===
    float3 directDiffuse  = computeDiffuse(lights, params, material, normal, in.worldPosition);
    float3 directSpecular = computeSpecular(lights, params, material, normal, in.worldPosition);

    float shadow = params.shadowsEnabled
        ? calculateShadow(in.shadowPosition, shadowTexture)
        : 1.0;
    directDiffuse *= shadow;

    // === IBL (зеркало логики из fragment_IBL) ===
    constexpr sampler ts(filter::linear, mip_filter::linear);
    constexpr sampler s(filter::linear, mip_filter::linear);

    float3 viewDir = normalize(in.worldPosition - params.cameraPosition);
    float3 refl    = reflect(viewDir, normal);

    float4 iblDiffuse = skyboxDiffuse.sample(ts, normal);
    //iblDiffuse.rgb = applySkyTransform(iblDiffuse.rgb, params);
    iblDiffuse = mix(pow(iblDiffuse, 0.2), iblDiffuse, material.metallic);
    float3 iblDiffuseColor = iblDiffuse.rgb * material.baseColor * (1.0 - material.metallic);

    float3 prefiltered = skybox.sample(s, refl, level(material.roughness * 5.0)).rgb;
    //prefiltered = applySkyTransform(prefiltered, params);
    float  nDotV       = saturate(dot(normal, -viewDir));
    float2 envBRDF     = brdfLut.sample(s, float2(material.roughness, nDotV)).rg;
    float3 f0          = mix(0.04, material.baseColor, material.metallic);
    float3 specIBL     = prefiltered * (f0 * envBRDF.r + envBRDF.g);

    float3 ambient = (iblDiffuseColor + specIBL) * material.ambientOcclusion;

    float3 color = directDiffuse + directSpecular + ambient;
    return float4(color, material.opacity);
}
