using namespace metal;
#include <metal_stdlib>
#include "Renderer.h"

struct VertexOut {
    float4 position [[position]];
    ushort aid [[render_target_array_index]];
    half4 color;
};

[[vertex]] VertexOut vertexShader(uint vid [[vertex_id]],
                                  ushort aid [[amplification_id]],
                                  constant VertexUniforms &uniforms [[buffer(1)]]) {
    float3 vertices[] = {
        float3(-1, 1, 0) / 2,
        float3(1, 1, 0) / 2,
        float3(1, 3, 0) / 2,

        float3(-1, 2, -0.4) / 4,
        float3(1, 2, -0.4) / 4,
        float3(-1, 4, -0.4) / 4,
    };
    auto v = vertices[vid];
    auto v4 = float4(v, 1);
    auto clip4 = uniforms.clipFromView[aid] * uniforms.viewFromOrigin[aid] * uniforms.originFromModel * v4;

    return {
        .position = clip4,
        .aid = aid,
        .color = vid < 3 ? half4(0, 0, 0.5, 1) : half4(1, 0, 0.5, 1),
    };
}

[[fragment]] half4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
