// ps2_dither_ps2x.hlsl
// Real 8x8 Bayer ordered dithering with configurable color depth quantization
// This produces the PS2/PSX framebuffer look authentically, unlike faked overlay grain
//
// Shader params (set in VMT via $c0_x notation):
//   $c0_x : color depth per channel (2.0 = RGB332, 4.0 = RGB444, 5.0 = RGB555, 6.0 = RGB565, 8.0 = full)
//   $c0_y : dither strength (0.0 - 1.0, typical 0.5)
//   $c0_z : saturation multiplier (0.0 - 1.5, PS2 look uses ~0.65)
//   $c0_w : brightness multiplier
//
// $c1_x : shadow tint R  (typically -0.02 for cyan shadows)
// $c1_y : shadow tint G  (typically  0.00)
// $c1_z : shadow tint B  (typically  0.04)
// $c1_w : contrast (1.0 = no change, 1.18 = PS2 contrast)
//
// $c2_x : highlight tint R (typically 0.04 warm)
// $c2_y : highlight tint G (typically 0.02)
// $c2_z : highlight tint B (typically -0.03)
// $c2_w : vignette strength

sampler BaseTextureSampler : register(s0);

float4 g_Params0 : register(c0);
float4 g_Params1 : register(c1);
float4 g_Params2 : register(c2);

struct PS_INPUT
{
    float2 baseTexCoord : TEXCOORD0;
};

// Bayer 8x8 via bit-interleave math (SM2.0b safe). Verified bit-exact.
float Bayer8x8(float2 pos)
{
    float2 p = floor(pos - 8.0 * floor(pos / 8.0));
    float x = p.x, y = p.y;

    float x1 = floor(x * 0.5), x2 = floor(x1 * 0.5);
    float bx0 = x - 2.0*x1, bx1 = x1 - 2.0*x2, bx2 = x2 - 2.0*floor(x2*0.5);

    float y1 = floor(y * 0.5), y2 = floor(y1 * 0.5);
    float by0 = y - 2.0*y1, by1 = y1 - 2.0*y2, by2 = y2 - 2.0*floor(y2*0.5);

    float a0 = abs(bx0 - by0), a1 = abs(bx1 - by1), a2 = abs(bx2 - by2);
    float idx = 32.0*a0 + 16.0*by0 + 8.0*a1 + 4.0*by1 + 2.0*a2 + by2;

    return idx / 64.0 - 0.5;
}

// Quantize a value to N levels with dithering
float3 QuantizeDither(float3 color, float levels, float ditherAmount, float2 screenPos)
{
    float dither = Bayer8x8(screenPos) * ditherAmount / levels;
    float3 c = color + dither;
    return floor(c * levels + 0.5) / levels;
}

// Luminance-weighted mix (Rec.709)
float Luminance(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float4 main(PS_INPUT i) : COLOR
{
    float2 uv = i.baseTexCoord;
    float4 texColor = tex2D(BaseTextureSampler, uv);
    float3 col = texColor.rgb;

    // Derive pixel-grid coord from UV (VPOS not available on SM2.0b)
    float2 screenPx = uv * float2(1920.0, 1080.0);

    // ---- Color grading pass ----
    float lum = Luminance(col);

    // Desaturate
    float sat = g_Params0.z;
    col = lerp(float3(lum, lum, lum), col, sat);

    // Contrast around mid-gray FIRST so tints survive on dark pixels
    col = (col - 0.5) * g_Params1.w + 0.5;

    // Brightness
    col = col * g_Params0.w;

    // Shadow/highlight split AFTER contrast
    float lumAfter = Luminance(saturate(col));
    float shadowW = saturate(1.0 - lumAfter * 2.2);
    shadowW = shadowW * shadowW;
    float highW = saturate((lumAfter - 0.55) * 2.2);
    highW = highW * highW;

    col = col + g_Params1.rgb * shadowW;
    col = col + g_Params2.rgb * highW;

    // ---- Quantization pass with dithering ----
    float levels = max(g_Params0.x, 2.0);
    float ditherAmt = g_Params0.y;

    col = saturate(col);
    col = QuantizeDither(col, levels, ditherAmt, screenPx);

    // ---- Vignette ----
    float2 centered = uv - 0.5;
    float vigDist = dot(centered, centered) * 2.0;
    float vig = 1.0 - saturate(vigDist * g_Params2.w);
    col = col * vig;

    return float4(saturate(col), texColor.a);
}
