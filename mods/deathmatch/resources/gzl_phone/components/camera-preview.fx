texture ScreenTexture;
float2 DrawSize = float2(1, 1);
float4 ClipRect = float4(0, 0, 1, 1);
float ClipRadius = 0;
float CameraRadius = 0;
float2 CropScale = float2(1, 1);
float Mirror = 0;
float4 ColorR = float4(1, 0, 0, 0);
float4 ColorG = float4(0, 1, 0, 0);
float4 ColorB = float4(0, 0, 1, 0);

sampler ScreenSampler = sampler_state
{
    Texture = <ScreenTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = None;
    AddressU = Clamp;
    AddressV = Clamp;
};

float roundedMask(float2 position, float2 size, float radius)
{
    float2 delta = abs(position - size * 0.5) - size * 0.5 + radius;
    float distance = length(max(delta, 0)) + min(max(delta.x, delta.y), 0) - radius;
    return saturate(0.5 - distance);
}

float4 main(float2 uv : TEXCOORD0, float4 diffuse : COLOR0) : COLOR0
{
    float2 sampleUV = (uv - 0.5) * CropScale + 0.5;
    sampleUV.x = lerp(sampleUV.x, 1 - sampleUV.x, Mirror);
    float4 texel = float4(tex2D(ScreenSampler, sampleUV).rgb, 1);
    float3 color = saturate(float3(dot(texel, ColorR), dot(texel, ColorG), dot(texel, ColorB)));
    float2 position = uv * DrawSize;
    float mask = roundedMask(position - ClipRect.xy, ClipRect.zw, ClipRadius);
    mask *= roundedMask(position, DrawSize, CameraRadius);
    return float4(color, mask) * diffuse;
}

technique CameraPreview
{
    pass P0
    {
        PixelShader = compile ps_2_0 main();
    }
}
