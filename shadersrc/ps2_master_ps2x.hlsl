// ps2_master_ps2x.hlsl
// Combined Haunting Ground / PS2 horror post-process -- all effects in a single pass.
// Target: pixel shader 2.0b (SM2.0b), the only profile Source's screenspace_general supports.
//
// IMPORTANT SM2.0b CONSTRAINTS THIS SHADER RESPECTS:
//   - No VPOS semantic (SM3.0+ only) -- screen coords are derived from UV.
//   - No 64-element indexed arrays -- Bayer is computed via bit-math.
//   - No dynamic branching -- effects blend via lerp, never `if`.
//   - No integer ops -- all "bits" work is on float 0/1 values.
//   - 96 ALU / 32 texture instruction budget is respected.
//   - No `sign()` on constants, no division by zero.
//
// Shader params (packed into c0..c3 float4 registers):
//   $c0_x : color depth levels (PS2 look ~6)
//   $c0_y : dither strength (0-1)
//   $c0_z : saturation (PS2 look ~0.45)
//   $c0_w : contrast (PS2 look ~1.18)
//
//   $c1_x : shadow R tint
//   $c1_y : shadow G tint
//   $c1_z : shadow B tint (positive = cyan push)
//   $c1_w : chromatic aberration amount (0-0.006)
//
//   $c2_x : highlight R tint (positive = warm)
//   $c2_y : highlight G tint
//   $c2_z : highlight B tint
//   $c2_w : vignette strength (0-1)
//
//   $c3_x : scanline strength (0-0.3)
//   $c3_y : scanline frequency (lines per screen height, typical ~540)
//   $c3_z : brightness multiplier
//   $c3_w : global effect blend (0 = off, 1 = full)

sampler BaseTextureSampler : register(s0);

float4 g_Params0 : register(c0);
float4 g_Params1 : register(c1);
float4 g_Params2 : register(c2);
float4 g_Params3 : register(c3);

struct PS_INPUT
{
    float2 baseTexCoord : TEXCOORD0;
};

// -----------------------------------------------------------------------------
// Bayer 8x8 via bit-interleave math (SM2.0b safe). Verified bit-exact against
// the canonical ordered-dither matrix.
// -----------------------------------------------------------------------------
float Bayer8x8(float2 pos)
{
    float2 p = floor(pos - 8.0 * floor(pos / 8.0));
    float x = p.x, y = p.y;

    float x1 = floor(x * 0.5);
    float x2 = floor(x1 * 0.5);
    float bx0 = x  - 2.0 * x1;
    float bx1 = x1 - 2.0 * x2;
    float bx2 = x2 - 2.0 * floor(x2 * 0.5);

    float y1 = floor(y * 0.5);
    float y2 = floor(y1 * 0.5);
    float by0 = y  - 2.0 * y1;
    float by1 = y1 - 2.0 * y2;
    float by2 = y2 - 2.0 * floor(y2 * 0.5);

    float a0 = abs(bx0 - by0);
    float a1 = abs(bx1 - by1);
    float a2 = abs(bx2 - by2);

    float idx = 32.0*a0 + 16.0*by0 + 8.0*a1 + 4.0*by1 + 2.0*a2 + by2;

    return idx / 64.0 - 0.5;
}

float Luminance(float3 c)
{
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

float4 main(PS_INPUT i) : COLOR
{
    float2 uv = i.baseTexCoord;

    // Derive a pixel-grid-like coord from UV for the Bayer pattern.
    // VPOS isn't available on SM2.0b, and we don't rely on any engine-supplied
    // size register (which differs per Source branch). Using a fixed 1920x1080
    // reference means the dither pattern scales with resolution -- which is
    // actually authentic since PS2 output was 480p.
    float2 screenPx = uv * float2(1920.0, 1080.0);

    // --- Chromatic aberration sampling ---
    float2 centered = uv - 0.5;
    float distSq = dot(centered, centered);
    float caFalloff = saturate(distSq * 4.0);
    float caAmount = g_Params1.w * caFalloff;

    // Smoothed left/right bias to avoid a seam at x=0.5
    float horizDir = clamp(centered.x * 10.0, -1.0, 1.0);
    float2 caOffset = float2(horizDir * caAmount, 0);

    float r = tex2D(BaseTextureSampler, uv + caOffset).r;
    float3 center = tex2D(BaseTextureSampler, uv).rgb;
    float b = tex2D(BaseTextureSampler, uv - caOffset).b;

    float3 col = float3(r, center.g, b);

    // --- Color grading ---
    float lum = Luminance(col);

    // Desaturate
    col = lerp(float3(lum, lum, lum), col, g_Params0.z);

    // Contrast around mid-gray FIRST, so tints can survive dark-crushing
    col = (col - 0.5) * g_Params0.w + 0.5;

    // Brightness
    col = col * g_Params3.z;

    // Shadow/highlight split (quadratic falloff) -- AFTER contrast so dark
    // pixels haven't been crushed to 0 yet when we add the tint
    float lumAfter = Luminance(saturate(col));
    float shadowW = saturate(1.0 - lumAfter * 2.2);
    shadowW = shadowW * shadowW;
    float highW = saturate((lumAfter - 0.55) * 2.2);
    highW = highW * highW;

    col = col + g_Params1.rgb * shadowW;
    col = col + g_Params2.rgb * highW;

    // --- Quantization with dithering ---
    col = saturate(col);
    float levels = max(g_Params0.x, 2.0);  // guard against div-by-zero-ish
    float ditherVal = Bayer8x8(screenPx) * g_Params0.y / levels;
    col = floor((col + ditherVal) * levels + 0.5) / levels;

    // --- Scanlines ---
    // Frequency is interpreted as "number of dark bands across screen height".
    // sin(v * freq * PI * 2) gives `freq` full cycles = `freq` dark bands.
    // Typical analog TV: 15-30 visible scanlines on a 1080p display.
    float scanline = sin(uv.y * g_Params3.y * 6.28318530718) * 0.5 + 0.5;
    scanline = 1.0 - (1.0 - scanline) * g_Params3.x;
    col = col * scanline;

    // --- Vignette ---
    float vig = 1.0 - saturate(distSq * 2.0 * g_Params2.w);
    col = col * vig;

    // Global effect blend
    float3 original = center;
    col = lerp(original, col, g_Params3.w);

    return float4(saturate(col), 1.0);
}
