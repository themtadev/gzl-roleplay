// GZL Blackjack - Table & Chair Tint Shader
// Eliminates over-exposed white bloom and tints felt & leather naturally
float4 gColor = float4(1.0, 1.0, 1.0, 1.0);
float gBrightness = 1.0;
texture gTexture;

sampler2D Sampler = sampler_state
{
    Texture = <gTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
};

float4 PixelShaderFunction(float2 TexCoords : TEXCOORD0) : COLOR0
{
    float4 texColor = tex2D(Sampler, TexCoords);
    float4 result = texColor * gColor * gBrightness;
    result.a = texColor.a;
    return result;
}

technique TintMaterial
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
    }
}

technique Fallback
{
    pass P0
    {
        Texture[0] = gTexture;
        MaterialAmbient = gColor;
        MaterialDiffuse = gColor;
    }
}
