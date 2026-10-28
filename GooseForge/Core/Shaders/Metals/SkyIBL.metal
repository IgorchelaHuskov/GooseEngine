//
//  SkyIBL.metal
//  GooseEngine
//
//  Created by Igorchela on 10.10.2026.
//

#include <metal_stdlib>
using namespace metal;


// Металлическое соглашение о кубмапах.

static inline float3 cubeDirection(uint face, float2 uv) {
    switch (face) {
        case 0: return float3( 1.0, -uv.y, -uv.x); // +X
        case 1: return float3(-1.0, -uv.y,  uv.x); // -X
        case 2: return float3( uv.x,  1.0,  uv.y); // +Y
        case 3: return float3( uv.x, -1.0, -uv.y); // -Y
        case 4: return float3( uv.x, -uv.y,  1.0); // +Z
        case 5: return float3(-uv.x, -uv.y, -1.0); // -Z
        default: return float3(0, 0, 1);
    }
}

static inline float radicalInverse(uint bits) {
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10;
}

static inline float2 hammersley(uint i, uint n) {
    return float2(float(i) / float(n), radicalInverse(i));
}

static inline float3 importanceSampleGGX(float2 Xi, float3 N, float roughness) {
    float a = roughness * roughness;
    float phi = 2.0 * M_PI_F * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a * a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    float3 H = float3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta);
    float3 up = abs(N.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 T = normalize(cross(up, N));
    float3 B = cross(N, T);
    return T * H.x + B * H.y + N * H.z;
}

// ─────────────────────────────────────────────
//  Irradiance — свёртка по полусфере
// ─────────────────────────────────────────────
kernel void irradiance_kernel(
    texturecube<float, access::sample> source [[texture(0)]],
    texturecube<float, access::write> target [[texture(1)]],
    uint3 gid [[thread_position_in_grid]])
{
    uint size = target.get_width();
    if (gid.x >= size || gid.y >= size) return;
    uint face = gid.z;

    float2 uv = (float2(gid.xy) + 0.5) / float(size) * 2.0 - 1.0;
    float3 N  = normalize(cubeDirection(face, uv));

    float3 up = abs(N.y) < 0.999 ? float3(0, 1, 0) : float3(1, 0, 0);
    float3 T  = normalize(cross(up, N));
    float3 B  = cross(N, T);

    constexpr sampler s(filter::linear);

    float3 irradiance = float3(0);
    float  samples    = 0;
    const float delta = 0.05;

    for (float phi = 0; phi < 2.0 * M_PI_F; phi += delta) {
        for (float theta = 0; theta < 0.5 * M_PI_F; theta += delta) {
            float3 ts = float3(sin(theta) * cos(phi),
                               sin(theta) * sin(phi),
                               cos(theta));
            float3 dir = T * ts.x + B * ts.y + N * ts.z;
            irradiance += source.sample(s, dir).rgb * cos(theta) * sin(theta);
            samples += 1.0;
        }
    }
    irradiance = M_PI_F * irradiance / samples;
    target.write(float4(irradiance, 1.0), gid.xy, face, 0);
}

// ─────────────────────────────────────────────
//  Prefilter — GGX importance sampling по мипам
// ─────────────────────────────────────────────
kernel void prefilter_kernel(
    texturecube<float, access::sample> source [[texture(0)]],
    texturecube<float, access::write> target  [[texture(1)]],
    constant float &roughness [[buffer(0)]],
    constant uint  &mipLevel  [[buffer(1)]],
    uint3 gid [[thread_position_in_grid]])
{
    uint size = target.get_width(mipLevel);
    if (gid.x >= size || gid.y >= size) return;
    uint face = gid.z;

    float2 uv = (float2(gid.xy) + 0.5) / float(size) * 2.0 - 1.0;
    float3 N = normalize(cubeDirection(face, uv));
    float3 V = N;

    constexpr sampler s(filter::linear, mip_filter::linear);

    const uint SAMPLE_COUNT = 1024u;
    float3 prefiltered = float3(0);
    float  totalWeight = 0.0;

    // Сэмплим из глубокого мипа источника — меньше шума на шершавых поверхностях.
    float sourceMip = roughness * 8.0;

    for (uint i = 0; i < SAMPLE_COUNT; ++i) {
        float2 Xi = hammersley(i, SAMPLE_COUNT);
        float3 H  = importanceSampleGGX(Xi, N, roughness);
        float3 L  = 2.0 * dot(V, H) * H - V;

        float nDotL = max(dot(N, L), 0.0);
        if (nDotL > 0.0) {
            prefiltered += source.sample(s, L, level(sourceMip)).rgb * nDotL;
            totalWeight += nDotL;
        }
    }
    prefiltered /= max(totalWeight, 0.0001);
    target.write(float4(prefiltered, 1.0), gid.xy, face, mipLevel);
}
