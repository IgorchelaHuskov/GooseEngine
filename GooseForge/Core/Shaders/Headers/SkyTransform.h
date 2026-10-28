//
//  SkyTransform.h
//  GooseEngine
//
//  Created by Igorchela on 10.10.2026.
//

#ifndef SkyTransform_h
#define SkyTransform_h

#import "Common.h"

//inline float3 applySkyTransform(float3 color, constant Params &params) {
//    // 1. Тонировка — до тонмапа, чтобы тайнтить линейный HDR
//    color *= params.skyTint;
//
//    // 2. Exposure (это и есть бывший brightness, но теперь честный exposure в линейном)
//    color *= params.skyBrightness;
//
//    // 3. Tonemap — Extended Reinhard с управляемым white point.
//    //    При color = whitePoint значение становится 1.0, всё что выше — мягко поджимается.
//    float wp = max(params.skyWhitePoint, 0.001);
//    float wp2 = wp * wp;
//    color = color * (1.0 + color / wp2) / (1.0 + color);
//
//    // 4. Насыщенность — уже после тонмапа, чтобы работала на LDR
//    float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
//    color = mix(float3(luma), color, 1.0 - params.skyDesaturation);
//
//    // 5. Гамма/контраст — теперь корректен, т.к. color в [0,1]
//    color = pow(saturate(color), float3(params.skyPower));
//
//    return color;
//}
#endif /* SkyTransform_h */
