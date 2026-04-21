// ps2_affine_ps2x.hlsl
// Subtle screen-space UV wobble. NOTE: This is NOT a faithful reproduction of
// PS2 affine texture mapping -- real PS2 affine is a vertex-space effect that
// only manifests during camera/geometry motion. A screen-space sin() warp is
// closer to "analog tape warp" or "heat shimmer" than PS2 wobble.
//
// This shader is best used at very low amounts (<=0.002) to add subtle
// atmospheric distortion. For authentic PS2 vertex snap/affine, a custom
// vertex shader is required (tracked separately).
//
// Target: SM2.0b. ~15 ALU + 1 tex.
//
// Shader params:
//   $c0_x : warp amount in UV units (0-0.005 typical, very subtle)
//   $c0_y : time phase (drive from Lua via CurrentTime material proxy)
//   $c0_z : wobble frequency (cycles across screen, typical 3-8)
//   $c0_w : vertical bias (0 = horizontal wobble only, 1 = vertical only)

sampler BaseTextureSampler : register(s0);
float4 g_Params0 : register(c0);

struct PS_INPUT
{
    float2 baseTexCoord : TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR
{
    float2 uv = i.baseTexCoord;

    // Horizon-biased: strongest in lower half of screen (floor wobble)
    float floorBias = saturate((uv.y - 0.5) * 2.0);
    floorBias = floorBias * floorBias;

    const float TWO_PI = 6.28318530718;

    // Two different-phase oscillators for X and Y so distortion isn't
    // visibly symmetric along a 45-degree line
    float wobbleX = sin(uv.x * g_Params0.z * TWO_PI + g_Params0.y * TWO_PI);
    float wobbleY = cos(uv.y * g_Params0.z * 4.0 + g_Params0.y * 3.14159265);

    float vBias = saturate(g_Params0.w);
    float2 distort;
    distort.x = wobbleX * (1.0 - vBias);
    distort.y = wobbleY * vBias;

    // Scale by warp amount and floor bias. No pixel quantization -- the previous
    // version used `floor()` on the distortion which at realistic defaults
    // rounded the Y axis to zero because the quant step exceeded the max amplitude.
    distort = distort * g_Params0.x * floorBias;

    return tex2D(BaseTextureSampler, uv + distort);
}
