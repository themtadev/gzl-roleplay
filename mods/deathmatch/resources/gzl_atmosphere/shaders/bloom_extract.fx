//---------------------------------------------------------------------
// GZL Atmosphere - Bright-Pass Luminance Extraction
// Thresholded high-luminance extraction with quadratic soft-knee
//---------------------------------------------------------------------

texture gScreenSource;
float gBloomThreshold = 0.82f;
float gBloomSoftKnee = 0.16f;

sampler2D SamplerScene = sampler_state
{
    Texture = <gScreenSource>;
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

float4 PixelShaderExtract(PSInput In) : COLOR0
{
    float3 color = tex2D(SamplerScene, In.TexCoord).rgb;
    float lum = dot(color, float3(0.2126f, 0.7152f, 0.0722f));

    // Quadratic soft knee curve
    float threshold = gBloomThreshold;
    float knee = max(gBloomSoftKnee, 0.001f);
    float soft = lum - threshold + knee;
    soft = clamp(soft, 0.0f, 2.0f * knee);
    soft = (soft * soft) / (4.0f * knee);

    float weight = max(soft, lum - threshold) / max(lum, 0.0001f);
    weight = saturate(weight);

    float3 extracted = color * weight;
    return float4(extracted, 1.0f);
}

technique ExtractPass
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderExtract();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = FALSE;
    }
}
