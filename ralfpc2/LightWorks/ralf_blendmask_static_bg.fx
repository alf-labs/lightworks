//--------------------------------------------------------------//
// Ralf Static Background Removal
//
// 3 tracks representing the same scene:
// - SG: Static background ("static ground") of the scene
// - BG: Background action of the scene
// - FG: Foreground action of the scene
//
// Computation:
// - if FG == SG, use BG, otherwise use FG.
//
// In other words: if foreground has action (!= static scene), use it.
// Otherwise default to the background action.
//
//--------------------------------------------------------------//
int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "Ralf Blend Static Background";       // The title
   string Category    = "Mixes";                  // Governs the category that the effect appears in in Lightworks
> = 0;

//--------------------------------------------------------------//
// Inputs
//--------------------------------------------------------------//

texture fg;
texture bg;
texture sg;

texture OutputPass1 : RenderColorTarget < float2 ViewportRatio={1.0,1.0}; >;

sampler FgSampler = sampler_state { Texture = <fg>; };
sampler BgSampler = sampler_state { Texture = <bg>; };
sampler SgSampler = sampler_state { Texture = <sg>; };
sampler P1Sampler = sampler_state { Texture = <OutputPass1>; };

//--------------------------------------------------------------//
// Define parameters here.
//
// The Lightworks application will automatically generate
// sliders/controls for all parameters which do not start
// with a a leading '_' character
//--------------------------------------------------------------//

int SetTechnique
<
   string Description = "Method";
   string Enum = "RGB,Colour,Luminosity";
> = 0;

float Threshold
<
   string Description = "Threshold";
   float MinVal = 0.00;
   float MaxVal = 1.00;
> = 0.05;

float Opacity
<
   string Description = "Fg Opacity";
   float MinVal = 0.00;
   float MaxVal = 1.00;
> = 1.0;

bool Reveal
<
   string Description = "Reveal";
> = false;

float ExcludeBelow
<
   string Description = "Exclude Below";
   float MinVal = -1.00;
   float MaxVal = 10.00;
> = 3.0;

float IncludeAbove
<
   string Description = "Include Above";
   float MinVal = -1.00;
   float MaxVal = 10.00;
> = 7.0;

float _OutputWidth  = 1.0;
float _OutputHeight = 1.0;

#pragma warning ( disable : 3571 )

//--------------------------------------------------------------
// Pixel Shader
//
// This section defines the code which the GPU will
// execute for every pixel in an output image.
//
// Note that pixels are processed out of order, in parallel.
// Using shader model 2.0, so there's a 64 instruction limit -
// use multple passes if you need more.
//--------------------------------------------------------------

// Reference: VS2005 shader language (HLSL)
// https://msdn.microsoft.com/en-us/library/windows/desktop/bb509615(v=vs.85).aspx
//
// Intrinsic functions:
// https://msdn.microsoft.com/en-us/library/windows/desktop/ff471376(v=vs.85).aspx
//
// Extra doc:
// https://www.lwks.com/index.php?option=com_kunena&func=view&catid=7&id=143678&Itemid=81


float4 ps_blend_rgb( float2 xy1 : TEXCOORD1 ) : COLOR {
    float4 fg = tex2D(FgSampler, xy1);
    float4 sg = tex2D(SgSampler, xy1);

    float4 ret = abs(fg - sg);
    float threshold = (ret.r + ret.g + ret.b) / 3.0;

    fg.a = (threshold < Threshold ? 0.0 : 1.0);
    return fg;
}

float4 ps_blend_chroma( float2 xy1 : TEXCOORD1 ) : COLOR {
    float4 fg = tex2D(FgSampler, xy1);
    float4 sg = tex2D(SgSampler, xy1);

    float fgCr = ( 0.439  * fg.r ) - ( 0.368 * fg.g ) - ( 0.071 * fg.b ) + 0.5;
    float fgCb = ( -0.148 * fg.r ) - ( 0.291 * fg.g ) + ( 0.439 * fg.b ) + 0.5;
    float sgCr = ( 0.439  * sg.r ) - ( 0.368 * sg.g ) - ( 0.071 * sg.b ) + 0.5;
    float sgCb = ( -0.148 * sg.r ) - ( 0.291 * sg.g ) + ( 0.439 * sg.b ) + 0.5;

    float threshold = ( abs(fgCr - sgCr) + abs(fgCb - sgCb) ) / 2.0;

    fg.a = (threshold < Threshold ? 0.0 : 1.0 );
    return fg;
}

float4 ps_blend_luma( float2 xy1 : TEXCOORD1 ) : COLOR {
    float4 fg = tex2D(FgSampler, xy1);
    float4 sg = tex2D(SgSampler, xy1);

    float fgY = ( 0.257 * fg.r ) + ( 0.504 * fg.g ) + ( 0.098 * fg.b ) + 0.0625;
    float sgY = ( 0.257 * sg.r ) + ( 0.504 * sg.g ) + ( 0.098 * sg.b ) + 0.0625;
    float threshold = abs(fgY - sgY);

    fg.a = (threshold < Threshold ? 0.0 : 1.0);
    return fg;
}

float4 ps_noise_redux_and_combine(float2 uv : TEXCOORD0, float2 xy2 : TEXCOORD2) : COLOR {
    float4 fg = tex2D(P1Sampler, uv );
    float4 bg = tex2D(BgSampler, xy2);

    float w1 = 1.0 / _OutputWidth;
    float h1 = 1.0 / _OutputHeight;

    float alpha = fg.a;

    uv.x -= w1;
    uv.y -= h1;
    float2 uv2 = uv;
    float alpha_sum = 0.0;
    for (int y = 0; y < 3; y++) {
        uv2.x = uv2.x;
        for (int x = 0; x < 3; x++) {
            uv2.x += w1;
            float4 f2 = tex2D(P1Sampler, uv2);
            alpha_sum += f2.a;
        }
        uv2.y += h1;
    }
    if (alpha_sum <= ExcludeBelow) { alpha = 0.0; }
    if (alpha_sum >= IncludeAbove) { alpha = 1.0; }
    
    if (Reveal) { fg = 1.0; }

    float4 ret = lerp(bg, fg, alpha * Opacity);
    ret.a = 1.0;

    return ret;
}



//--------------------------------------------------------------
// Technique
//
// Specifies the order of passes (we only have a single pass, so
// there's not much to do)
//--------------------------------------------------------------

technique RGB {
    pass Pass1 <
        string Script = "RenderColorTarget0 = OutputPass1;";
    > { 
        PixelShader = compile PROFILE ps_blend_rgb();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}

technique Colour {
    pass Pass1 <
        string Script = "RenderColorTarget0 = OutputPass1;";
    > { 
        PixelShader = compile PROFILE ps_blend_chroma();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}

technique Luminosity {
    pass Pass1 <
        string Script = "RenderColorTarget0 = OutputPass1;";
    > { 
        PixelShader = compile PROFILE ps_blend_luma();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}
