//
//  Shading.h
//  GooseEngine
//
//  Created by Igorchela on 05.10.2026.
//

#ifndef Shading_h
#define Shading_h

#import "Common.h"
#import "Lighting.h"

// Один switch на все типы света. Добавил тип — добавил case.
inline float3 shadeLight(Light L,
                         Material mat,
                         float3 N, float3 V, float3 P,
                         float shadowFactor)
{
    switch (L.type) {
        case Sun:
            return (calculateSunDiffuse(L, N, mat) +
                    calculateSunSpecular(L, mat, V, N)) * shadowFactor;

        case Point:
            return calculatePointDiffuse(L, N, mat, P);
            // + point specular когда напишешь

        case Spot:
            return calculateSpotDiffuse(L, N, mat, P);   // ← новая функция, но интерфейс тот же
            // + spot specular

        case Ambient:
            return mat.baseColor * L.color * L.intensity;

        default:
            return 0;
    }
}

// Нужен ли свету объёмный проход? Одна точка правды.
inline bool isVolumeLight(LightType t) {
    return t == Point || t == Spot;
}


#endif /* Shading_h */
