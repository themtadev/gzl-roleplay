// GZL Creator - Alpha Hide Shader
// Foolproof DirectX render state to discard geometry

technique HidePart
{
    pass P0
    {
        AlphaTestEnable = TRUE;
        AlphaRef = 255;
        AlphaFunc = Greater;
        AlphaBlendEnable = TRUE;
        SrcBlend = ZERO;
        DestBlend = ONE;
    }
}
