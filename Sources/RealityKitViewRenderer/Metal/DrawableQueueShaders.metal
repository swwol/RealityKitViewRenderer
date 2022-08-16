#include <metal_stdlib>
using namespace metal;

constexpr sampler samplerBilinear(coord::normalized,
                                  address::repeat,
                                  filter::linear,
                                  mip_filter::nearest);

static float srgbToLinear(float c) {
    if (c <= 0.04045)
        return c / 12.92;
    else
        return powr((c + 0.055) / 1.055, 2.4);
}



typedef struct {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} DrawableVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
} DrawableColorInOut;

vertex DrawableColorInOut drawableQueueVertexShader(DrawableVertex in [[stage_in]]) {
    DrawableColorInOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment half4 drawableQueueFragmentShader(DrawableColorInOut inputVertex [[ stage_in ]],
                              texture2d<float, access::sample> texture [[ texture(0) ]]) {
  float2 uv = inputVertex.texCoord;
  uv.y = 1.0 - uv.y;
    half4 color = half4(texture.sample(samplerBilinear, uv));

  color.r = srgbToLinear(color.r);
  color.g = srgbToLinear(color.g);
  color.b = srgbToLinear(color.b);
  return color;
}

