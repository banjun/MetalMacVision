#ifdef __METAL_VERSION__
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

struct VertexUniforms {
    simd_float4x4 originFromModel;
    simd_float4x4 viewFromOrigin[2];
    simd_float4x4 clipFromView[2];
};
