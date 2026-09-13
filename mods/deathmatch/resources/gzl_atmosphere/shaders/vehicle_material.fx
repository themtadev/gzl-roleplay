//---------------------------------------------------------------------
// GZL Atmosphere - Vehicle Material & Clearcoat Response
// Subtle physical Fresnel clearcoat, smooth directional specular rolloff
// Retains vertex colors, damage, liveries, strictly avoids fake chrome
//---------------------------------------------------------------------

texture gTexture;
float4x4 gWorld : WORLD;
float4x4 gView : VIEW;
float4x4 gProjection : PROJECTION;
float4x4 gWorldViewProjection : WORLDVIEWPROJECTION;
float3 gCameraPosition : CAMERAPOSITION;

float3 gSunDir = float3(0.0f, 0.707f, 0.707f);
float3 gSunColor = float3(1.0f, 0.95f, 0.88f);
float3 gAmbientColor = float3(0.38f, 0.40f, 0.45f);
float gClearcoatStrength = 0.28f;

sampler2D SamplerBase = sampler_state
{
    Texture = <gTexture>;
    AddressU = Wrap;
    AddressV = Wrap;
    MinFilter = Linear;
    MagFilter = Linear;
    MipFilter = Linear;
};

struct VSInput
{
    float4 Position : POSITION0;
    float3 Normal   : NORMAL0;
    float2 TexCoord : TEXCOORD0;
    float4 Diffuse  : COLOR0;
};

struct VSOutput
{
    float4 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float3 Normal   : TEXCOORD1;
    float3 ViewDir  : TEXCOORD2;
    float4 Diffuse  : COLOR0;
};

VSOutput VertexShaderVehicle(VSInput In)
{
    VSOutput Out;
    Out.Position = mul(In.Position, gWorldViewProjection);
    Out.TexCoord = In.TexCoord;
    Out.Diffuse = In.Diffuse;

    float3 worldPos = mul(In.Position, gWorld).xyz;
    Out.Normal = normalize(mul(In.Normal, (float3x3)gWorld));
    Out.ViewDir = normalize(gCameraPosition - worldPos);

    return Out;
}

float4 PixelShaderVehicle(VSOutput In) : COLOR0
{
    float4 baseTex = tex2D(SamplerBase, In.TexCoord);
    float3 normal = normalize(In.Normal);
    float3 viewDir = normalize(In.ViewDir);
    float3 lightDir = normalize(gSunDir);

    float NdotL = saturate(dot(normal, lightDir));
    float NdotV = saturate(dot(normal, viewDir));

    // Vehicle vertex color carries GTA vehicle color, shading & damage
    float3 bodyColor = baseTex.rgb * In.Diffuse.rgb;

    // 1. Directional Sun Specular (Blinn-Phong)
    float3 halfVector = normalize(lightDir + viewDir);
    float NdotH = saturate(dot(normal, halfVector));
    float specular = pow(NdotH, 32.0f) * NdotL * 0.35f;

    // 2. Clearcoat Fresnel Edge Sheen
    // Schlick Fresnel approximation for automotive clearcoat (n=1.5 -> F0=0.04)
    float fresnel = 0.04f + 0.96f * pow(1.0f - NdotV, 5.0f);
    float3 clearcoatSheen = gAmbientColor * fresnel * gClearcoatStrength;

    // 3. Composite vehicle lighting
    float3 finalColor = bodyColor + (gSunColor * specular * gClearcoatStrength) + clearcoatSheen;

    return float4(finalColor, baseTex.a);
}

technique VehiclePaint
{
    pass P0
    {
        VertexShader = compile vs_3_0 VertexShaderVehicle();
        PixelShader = compile ps_3_0 PixelShaderVehicle();
    }
}

technique Fallback
{
    pass P0
    {
        Texture[0] = gTexture;
    }
}
