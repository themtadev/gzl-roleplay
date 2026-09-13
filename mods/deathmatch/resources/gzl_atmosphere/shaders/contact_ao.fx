//---------------------------------------------------------------------
// GZL Atmosphere - Depth-Aware Contact Grounding (SSAO)
// Short-radius grounding for feet, tires, shelves, and architectural seams
// Halo-free with strict geometric rejection and interior profile adaptation
//---------------------------------------------------------------------

texture gDepthBuffer : DEPTHBUFFER;
matrix gProjectionMainScene : PROJECTION_MAIN_SCENE;

float2 gScreenSize = float2(1920.0f, 1080.0f);
float gAORadius = 0.85f;          // Radius in world meters
float gAOThickness = 0.32f;       // Max depth difference before sample is rejected (anti-halo)
float gAOMaxDistance = 32.0f;     // Max distance for contact depth in meters
float gAOIntensity = 1.0f;
float gInteriorFactor = 0.0f;

sampler SamplerDepth = sampler_state
{
    Texture = (gDepthBuffer);
    AddressU = Clamp;
    AddressV = Clamp;
    MinFilter = Point;
    MagFilter = Point;
    MipFilter = None;
};

struct PSInput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
};

float FetchDepth(float2 uv)
{
    float4 texel = tex2D(SamplerDepth, uv);
#if IS_DEPTHBUFFER_RAWZ
    float3 rawval = floor(255.0f * texel.arg + 0.5f);
    float3 valueScaler = float3(0.996093809371817670572857294849f, 0.0038909914428586627756752238080039f, 1.5199185323666651467481343000015e-5f);
    return dot(rawval, valueScaler / 255.0f);
#else
    return texel.r;
#endif
}

float Linearize(float posZ)
{
    return gProjectionMainScene[3][2] / (posZ - gProjectionMainScene[2][2]);
}

// Fixed 8-point Poisson spiral kernel
static const float2 cOffsets[8] = {
    float2( 0.000f,  0.250f),
    float2(-0.350f, -0.150f),
    float2( 0.450f, -0.300f),
    float2(-0.200f,  0.600f),
    float2( 0.700f,  0.250f),
    float2(-0.750f, -0.400f),
    float2( 0.350f, -0.800f),
    float2(-0.850f,  0.450f)
};

float4 PS_ContactAO(PSInput In) : COLOR0
{
    float2 uv = In.TexCoord;
    float rawDepth = FetchDepth(uv);

    // Reject sky or invalid buffer values
    if (rawDepth >= 0.9999f || rawDepth <= 0.0001f)
    {
        return float4(1.0f, 1.0f, 1.0f, 1.0f);
    }

    float z0 = Linearize(rawDepth);

    // Reject if too close (viewmodel/camera clipping) or beyond max grounding range
    if (z0 < 0.25f || z0 > gAOMaxDistance)
    {
        return float4(1.0f, 1.0f, 1.0f, 1.0f);
    }

    // Distance fade (fades out gracefully between 70% and 100% of max distance)
    float distFade = saturate((gAOMaxDistance - z0) / (gAOMaxDistance * 0.3f));

    // World-space radius projected to screen coordinates
    float effectiveRadius = (gAORadius * (1.0f + gInteriorFactor * 0.25f)) / max(z0, 0.5f);
    // Clamp screen radius to prevent giant sweeps up close
    effectiveRadius = min(effectiveRadius, 0.05f);

    float2 pixelAspect = float2(1.0f, gScreenSize.x / gScreenSize.y);
    float thickness = gAOThickness * (1.0f + gInteriorFactor * 0.15f);

    float occlusion = 0.0f;
    float validSamples = 0.0f;

    [unroll]
    for (int i = 0; i < 8; ++i)
    {
        float2 sampleUV = uv + cOffsets[i] * effectiveRadius * pixelAspect;
        float sampleRaw = FetchDepth(sampleUV);

        if (sampleRaw < 0.9999f)
        {
            float zn = Linearize(sampleRaw);
            float diff = z0 - zn;

            // Sample must be in front of center pixel, but within thickness threshold
            if (diff > 0.006f && diff < thickness)
            {
                // Falloff: strongest occlusion when depth difference is minimal (contact point)
                float weight = 1.0f - (diff / thickness);
                occlusion += weight * weight;
            }
            validSamples += 1.0f;
        }
    }

    float ao = 1.0f;
    if (validSamples > 0.0f)
    {
        float normOcc = (occlusion / validSamples) * gAOIntensity * (1.0f + gInteriorFactor * 0.35f);
        ao = saturate(1.0f - normOcc * distFade);
    }

    return float4(ao, ao, ao, 1.0f);
}

technique ContactAO
{
    pass P0
    {
        PixelShader = compile ps_3_0 PS_ContactAO();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = FALSE;
    }
}

technique Fallback
{
    pass P0
    {
    }
}
