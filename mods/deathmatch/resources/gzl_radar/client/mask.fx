texture gTexture;
texture gMaskTexture;
float2 gPlayerUV;
float gAngle;
float gZoom;

sampler TextureSampler = sampler_state
{
    Texture = <gTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

sampler MaskSampler = sampler_state
{
    Texture = <gMaskTexture>;
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
    
    float cosA = cos(gAngle);
    float sinA = sin(gAngle);
    float2 rotated = float2(
        centered.x * cosA - centered.y * sinA,
        centered.x * sinA + centered.y * cosA
    );
    
    float2 mapUV = gPlayerUV + rotated * gZoom;
    
    float4 rawColor = tex2D(TextureSampler, mapUV);
    float4 maskColor = tex2D(MaskSampler, input.TexCoord);
    
    float lum = dot(rawColor.rgb, float3(0.299, 0.587, 0.114));
    
    float roadFactor = 1.0 - smoothstep(0.12, 0.38, lum);
    float buildingFactor = smoothstep(0.35, 0.52, lum) * (1.0 - smoothstep(0.55, 0.72, lum));
    
    float3 darkBg = float3(0.09, 0.11, 0.14);
    float3 buildingCol = float3(0.15, 0.18, 0.22);
    float3 roadCol = float3(0.62, 0.66, 0.70);
    
    float3 finalRGB = lerp(darkBg, buildingCol, buildingFactor);
    finalRGB = lerp(finalRGB, roadCol, roadFactor);
    
    float finalAlpha = lerp(0.72, 0.88, roadFactor) * maskColor.a;
    
    return float4(finalRGB * input.Diffuse.rgb, finalAlpha * input.Diffuse.a);
}

technique RadarTechnique
{
    pass P0
    {
        PixelShader = compile ps_2_0 PixelShaderFunction();
    }
}
