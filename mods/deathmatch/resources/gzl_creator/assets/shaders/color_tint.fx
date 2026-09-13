// GZL Creator - Color Tint Shader
// Multiplies texture diffuse with dynamic RGBA color for skin tone and hair color

float4 gColor = float4(1.0, 1.0, 1.0, 1.0);
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
    return texColor * gColor;
}

technique TintColor
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
