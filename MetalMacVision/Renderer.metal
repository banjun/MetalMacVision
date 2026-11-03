using namespace metal;
#include <metal_stdlib>
#include "Renderer.h"

struct VertexOut {
    float4 position [[position]];
    ushort aid [[render_target_array_index]];
};

[[vertex]] VertexOut vertexShader(uint vid [[vertex_id]],
                                  ushort aid [[amplification_id]],
                                  constant VertexUniforms &uniforms [[buffer(1)]]) {
    float3 vertices[] = {
        float3(-1, 0, 0) / 2,
        float3(1, 0, 0) / 2,
        float3(1, 2, 0) / 2,
    };
    auto v = vertices[vid];
    auto v4 = float4(v, 1);
    auto clip4 = uniforms.clipFromView[aid] * uniforms.viewFromOrigin[aid] * uniforms.originFromModel * v4;

    return {
        .position = clip4,
        .aid = aid,
    };
}

[[fragment]] half4 fragmentShader() {
    return half4(0, 0, 0.5, 0.5);
}
