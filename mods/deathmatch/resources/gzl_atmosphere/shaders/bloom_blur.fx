//---------------------------------------------------------------------
// GZL Atmosphere - Separable Bilinear Gaussian Blur
// Efficient 5-sample blur with 9-sample effective coverage
//---------------------------------------------------------------------

texture gBlurSource;
float2 gDirection = float2(1.0f, 0.0f);
float2 gTexelSize = float2(1.0f / 480.0f, 1.0f / 270.0f);
float gBlurSpread = 1.0f;

sampler2D SamplerSource = sampler_state
{
    Texture = <gBlurSource>;
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

float4 PixelShaderBlur(PSInput In) : COLOR0
{
    float2 uv = In.TexCoord;
    float2 step = gDirection * gTexelSize * gBlurSpread;

    // Center sample
    float3 color = tex2D(SamplerSource, uv).rgb * 0.2270270270f;

    // Symmetric linear-offset samples
    float2 offset1 = step * 1.3846153846f;
    float2 offset2 = step * 3.2307692308f;

    color += tex2D(SamplerSource, uv + offset1).rgb * 0.3162162162f;
    color += tex2D(SamplerSource, uv - offset1).rgb * 0.3162162162f;

    color += tex2D(SamplerSource, uv + offset2).rgb * 0.0702702703f;
    color += tex2D(SamplerSource, uv - offset2).rgb * 0.0702702703f;

    return float4(color, 1.0f);
}

technique BlurPass
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderBlur();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = FALSE;
    }
}
