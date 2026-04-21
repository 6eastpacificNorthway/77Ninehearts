// ps2_crt_ps2x.hlsl
// Subtle CRT/composite video simulation -- "played on a tube TV" not "arcade monitor".
//   - Horizontal chroma blur (composite kept luma sharp, bled chroma)
//   - Faint scanlines
//   - Mild barrel distortion
// Target: SM2.0b. ~30 ALU + 3 tex.
//
// Shader params:
//   $c0_x : scanline strength (0.0 - 0.3, typical 0.08)
//   $c0_y : scanline frequency (lines across screen height, typical 540)
//   $c0_z : chroma blur width in UV (typical 0.002)
//   $c0_w : barrel distortion (0.0 - 0.1, typical 0.02)

sampler BaseTextureSampler : register(s0);
float4 g_Params0 : register(c0);

struct PS_INPUT
{
    float2 baseTexCoord : TEXCOORD0;
};

// YIQ color space -- composite video was encoded in YIQ (NTSC). Y = luma, I/Q = chroma.
float3 RGB2YIQ(float3 c)
{
    return float3(
        dot(c, float3(0.299,  0.587,  0.114)),
        dot(c, float3(0.596, -0.274, -0.322)),
        dot(c, float3(0.211, -0.523,  0.312))
    );
}

float3 YIQ2RGB(float3 c)
{
    return float3(
        dot(c, float3(1.0,  0.956,  0.621)),
        dot(c, float3(1.0, -0.272, -0.647)),
        dot(c, float3(1.0, -1.106,  1.703))
    );
}

float4 main(PS_INPUT i) : COLOR
{
    float2 uv = i.baseTexCoord;

    // --- Mild barrel distortion ---
    float2 centered = uv - 0.5;
    float r2 = dot(centered, centered);
    float2 distortedUV = centered * (1.0 + r2 * g_Params0.w) + 0.5;

    // Fade instead of clamp: darken pixels where the barrel pushed UV outside.
    // This avoids the hard "piled up pixels" streak at screen edges.
    float2 uvDist = max(-distortedUV, distortedUV - 1.0);
    float edgeFade = 1.0 - saturate(max(uvDist.x, uvDist.y) * 8.0);
    distortedUV = saturate(distortedUV);

    // --- Chroma blur in YIQ ---
    float chromaBlur = g_Params0.z;
    float3 cC = tex2D(BaseTextureSampler, distortedUV).rgb;
    float3 cL = tex2D(BaseTextureSampler, distortedUV + float2(-chromaBlur, 0)).rgb;
    float3 cR = tex2D(BaseTextureSampler, distortedUV + float2( chromaBlur, 0)).rgb;

    float3 yiqC = RGB2YIQ(cC);
    float3 yiqL = RGB2YIQ(cL);
    float3 yiqR = RGB2YIQ(cR);

    // Keep luma sharp, blur chroma
    float3 yiqOut = float3(
        yiqC.x,
        (yiqL.y + yiqC.y * 2.0 + yiqR.y) * 0.25,
        (yiqL.z + yiqC.z * 2.0 + yiqR.z) * 0.25
    );

    float3 col = YIQ2RGB(yiqOut);

    // --- Scanlines ---
    // Frequency is interpreted as "number of dark bands across screen height".
    // At 30 bands on a 1080p screen, each band is ~36px tall -- clearly visible.
    float scanline = sin(i.baseTexCoord.y * g_Params0.y * 6.28318530718) * 0.5 + 0.5;
    scanline = 1.0 - (1.0 - scanline) * g_Params0.x;
    col = col * scanline * edgeFade;

    return float4(saturate(col), 1.0);
}

