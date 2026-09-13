texture gTexture;

technique PlateReplace
{
    pass P0
    {
        Texture[0] = gTexture;
    }
}