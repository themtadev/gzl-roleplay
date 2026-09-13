texture gTexture;
float2 gCenterUV;
float gZoom;
float gAspect;

sampler TextureSampler = sampler_state
{
    Texture = <gTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

struct VertexShaderOutput
{
    float4 Position : POSITION0;
    float4 Diffuse  : COLOR0;
    float2 TexCoord : TEXCOORD0;
};

float4 PixelShaderFunction(VertexShaderOutput input) : COLOR0
{
    float2 centered = input.TexCoord - 0.5;
    centered.x *= gAspect;
    
    float2 mapUV = gCenterUV + centered * gZoom;
    
    if (mapUV.x < 0.0 || mapUV.x > 1.0 || mapUV.y < 0.0 || mapUV.y > 1.0)
    {
        return float4(0.08, 0.10, 0.13, 1.0) * input.Diffuse;
    }
    
    float4 rawColor = tex2D(TextureSampler, mapUV);
    float lum = dot(rawColor.rgb, float3(0.299, 0.587, 0.114));
    
    float roadFactor = 1.0 - smoothstep(0.12, 0.38, lum);
    float buildingFactor = smoothstep(0.35, 0.52, lum) * (1.0 - smoothstep(0.55, 0.72, lum));
    
    float3 darkBg = float3(0.10, 0.12, 0.15);
    float3 buildingCol = float3(0.16, 0.19, 0.23);
    float3 roadCol = float3(0.68, 0.72, 0.76);
    
    float3 finalRGB = lerp(darkBg, buildingCol, buildingFactor);
    finalRGB = lerp(finalRGB, roadCol, roadFactor);
    
    return float4(finalRGB * input.Diffuse.rgb, input.Diffuse.a);
}

technique MapTechnique
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
