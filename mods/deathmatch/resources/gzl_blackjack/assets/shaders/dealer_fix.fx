// GZL Blackjack - Dealer Clothing Fix Shader
// Forces clothing materials to render 100% solid and opaque, preventing transparent sleeve / alpha punch-through bugs
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
    texColor.a = 1.0;
    return texColor;
}

technique FixOpaque
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
        ZEnable = TRUE;
        ZWriteEnable = TRUE;
    }
}

technique Fallback
{
    pass P0
    {
        Texture[0] = gTexture;
        AlphaBlendEnable = FALSE;
        AlphaTestEnable = FALSE;
    }
}
