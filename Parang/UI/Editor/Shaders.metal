#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                            constant VertexIn* vertices [[buffer(0)]]) {
    VertexOut out;
    VertexIn in = vertices[vertexID];
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]],
                             texture2d<float> videoTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear,
                                   min_filter::linear,
                                   address::clamp_to_edge);
    return videoTexture.sample(textureSampler, in.texCoord);
} 