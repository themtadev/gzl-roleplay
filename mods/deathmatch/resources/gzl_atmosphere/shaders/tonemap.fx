//---------------------------------------------------------------------
// GZL Atmosphere - Filmic Tone Mapper & Master Color Pipeline
// High dynamic range reconstruction, ACES curve, halo-free sharpening
//---------------------------------------------------------------------

texture gScreenSource;
texture gBloomTexture;
texture gAOTexture;

float gExposure = 1.0f;
float gBloomEnabled = 0.0f;
float gBloomIntensity = 0.35f;
float gAOEnabled = 0.0f;
float gAOIntensity = 0.45f;
float gContrast = 1.08f;
float gSaturation = 1.05f;
float gVibrance = 0.08f;
float gHighlightRollOff = 1.0f;
float gShadowToe = 0.015f;
float3 gColorFilter = float3(0.98f, 1.0f, 1.04f);
float gSharpenEnabled = 1.0f;
float gSharpenStrength = 0.22f;
float2 gScreenSize = float2(1920.0f, 1080.0f);
float gInteriorFactor = 0.0f;

sampler2D SamplerScene = sampler_state
{
    Texture = <gScreenSource>;
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
};

sampler2D SamplerBloom = sampler_state
{
    Texture = <gBloomTexture>;
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

sampler2D SamplerAO = sampler_state
{
    Texture = <gAOTexture>;
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
};

struct PSInput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
};

float Lum(float3 c)
{
    return dot(c, float3(0.2126f, 0.7152f, 0.0722f));
}

// Narkowicz ACES filmic approximation
float3 ACESFilm(float3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

float4 PixelShaderTonemap(PSInput In) : COLOR0
{
    float2 uv = In.TexCoord;
    float2 pixel = 1.0f / gScreenSize;

    // 1. Halo-free 5-tap sharpening
    float3 center = tex2D(SamplerScene, uv).rgb;
    float3 sceneColor = center;

    if (gSharpenEnabled > 0.5f)
    {
        float3 up    = tex2D(SamplerScene, uv + float2(0.0f, -pixel.y)).rgb;
        float3 down  = tex2D(SamplerScene, uv + float2(0.0f, pixel.y)).rgb;
        float3 left  = tex2D(SamplerScene, uv + float2(-pixel.x, 0.0f)).rgb;
        float3 right = tex2D(SamplerScene, uv + float2(pixel.x, 0.0f)).rgb;

        float3 blur = (up + down + left + right) * 0.25f;
        float3 sharp = center + (center - blur) * gSharpenStrength;

        // Anti-ringing clamp to local min/max
        float3 minC = min(center, min(min(up, down), min(left, right)));
        float3 maxC = max(center, max(max(up, down), max(left, right)));
        sceneColor = clamp(sharp, minC, maxC);
    }

    // 2. Contact Depth (SSAO) modulation
    if (gAOEnabled > 0.5f)
    {
        float ao = tex2D(SamplerAO, uv).r;
        // Protect direct bright highlights and emissive surfaces from dirty AO
        float l = Lum(sceneColor);
        float highlightProt = smoothstep(0.35f, 0.85f, l);
        float effectiveAO = lerp(ao, 1.0f, highlightProt);
        sceneColor *= lerp(1.0f, effectiveAO, gAOIntensity);
    }

    // 3. Pre-tonemap Bloom Composite
    if (gBloomEnabled > 0.5f)
    {
        float3 bloom = tex2D(SamplerBloom, uv).rgb;
        sceneColor += bloom * gBloomIntensity;
    }

    // 4. Exposure & White Balance Adjustment
    sceneColor *= gExposure;
    sceneColor *= gColorFilter;

    // Interior profile adjustments (neutralize warmth, slight local contrast)
    if (gInteriorFactor > 0.01f)
    {
        // Neutralize GTA SA orange interior cast toward clean modern retail lighting
        float3 interiorFilter = float3(0.96f, 0.99f, 1.05f);
        sceneColor = lerp(sceneColor, sceneColor * interiorFilter, gInteriorFactor * 0.7f);
    }

    // 5. Filmic Tone Mapping (Chrominance-preserving ACES)
    float inLum = Lum(sceneColor);
    float mappedLum = ACESFilm(float3(inLum, inLum, inLum)).r;
    float3 perChannel = ACESFilm(sceneColor);
    float3 lumPreserved = sceneColor * (mappedLum / max(inLum, 0.0001f));
    // Blend: 65% luminance mapping + 35% per-channel for natural highlight desaturation
    float3 graded = lerp(lumPreserved, perChannel, 0.35f);

    // 6. Contrast S-Curve
    float contrastVal = gContrast + gInteriorFactor * 0.06f;
    graded = saturate((graded - 0.5f) * contrastVal + 0.5f);

    // 7. Vibrance & Saturation
    float finalLum = Lum(graded);
    float maxC = max(graded.r, max(graded.g, graded.b));
    float minC = min(graded.r, min(graded.g, graded.b));
    float satDelta = maxC - minC;
    float vib = (1.0f - satDelta) * gVibrance;
    float targetSat = gSaturation + vib - gInteriorFactor * 0.03f;
    graded = lerp(float3(finalLum, finalLum, finalLum), graded, max(targetSat, 0.0f));

    // 8. Controlled Shadow Grounding (toe lift prevents crushing)
    graded = max(graded, gShadowToe);

    return float4(graded, 1.0f);
}

// Low-profile fallback for legacy pixel shader 2.0
float4 PixelShaderFallback(PSInput In) : COLOR0
{
    float3 c = tex2D(SamplerScene, In.TexCoord).rgb;
    c *= gExposure;
    c = saturate((c - 0.5f) * 1.05f + 0.5f);
    return float4(c, 1.0f);
}

technique TonemapMaster
{
    pass P0
    {
        PixelShader = compile ps_3_0 PixelShaderTonemap();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = FALSE;
    }
}

technique TonemapFallback
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFallback();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = FALSE;
    }
}
