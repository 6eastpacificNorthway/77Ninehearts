// ps2_chroma_ps2x.hlsl
// Chromatic aberration only -- for testing/tuning, or stacking over other effects.
// Target: SM2.0b. ~15 ALU + 3 tex.
//
// Shader params:
//   $c0_x : aberration strength in UV units (0.001 - 0.01 typical)
//   $c0_y : radial falloff power (1.0 = linear, 2.0 = quadratic)
//   $c0_z : horizontal bias (1.0 = mostly horizontal like composite, 0.0 = radial)
//   $c0_w : unused

sampler BaseTextureSampler : register(s0);
float4 g_Params0 : register(c0);

struct PS_INPUT
{
    float2 baseTexCoord : TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR
{
    float2 uv = i.baseTexCoord;
    float2 centered = uv - 0.5;

    // length^2 is cheap; use it with pow for the falloff curve
    float distSq = dot(centered, centered);
    float falloff = pow(saturate(distSq * 4.0), g_Params0.y * 0.5);

    // Horizontal bias: blend between radial direction and pure horizontal.
    // Avoid `normalize` to prevent div-by-zero at uv=(0.5,0.5). Instead,
    // use a tiny offset and scale manually.
    float invLen = 1.0 / (sqrt(distSq) + 0.0001);
    float2 radialDir = centered * invLen;
    float horizSign = clamp(centered.x * 20.0, -1.0, 1.0);
    float2 horizDir = float2(horizSign, 0);

    float2 dir = lerp(radialDir, horizDir, saturate(g_Params0.z));

    float2 offset = dir * g_Params0.x * falloff;

    float r = tex2D(BaseTextureSampler, uv + offset).r;
    float3 c = tex2D(BaseTextureSampler, uv).rgb;
    float b = tex2D(BaseTextureSampler, uv - offset).b;

    return float4(r, c.g, b, 1.0);
}
