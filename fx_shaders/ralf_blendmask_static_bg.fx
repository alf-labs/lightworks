//--------------------------------------------------------------//
// Author: Ralf <ralfoide at gmail>
// Effect: Static Background Blending Mask
//
//-------------
// Description: This effect is a sort of cheap rotoscoping fx for a very
// specific case where 2 videos clips are taken for the exact same scene
// with a fixed camera setup. One clip is considered the background and
// used as-is. The second clip is considered the foreground. Delta from
// the foreground is extracted by comparing with a reference background
// (typically a clip of the scene with no motion at all).
// The foreground delta is then blended on top of the background clip.
// 
//-------
// Usage:
//
// 3 tracks representing the same scene:
// - SG: Reference  clip ("aka static background") of the scene
// - BG: Background clip of the scene
// - FG: Foreground clip of the scene
//
// Computation:
// - if FG == SG, use BG, otherwise use FG.
//
// In other words: if foreground has action (!= static scene), use it.
// Otherwise default to the background action.
//
// Implementation in 2 passes:
// - Pass 1: Diff FG vs SG. Compare with threshold. Generate FG with alpha = 0 or 1.
// - Pass 2: Naive/cheap noise reduction on alpha mask + combine FG with BG.
//
// The noise reduction sums the alpha of a 3x3 pixel box. This acts on the mask generated
// in pass 1. If a mask pixel doesn't have enough neighbors, it's probably noise.
// If it has many neighbors, it's probably part of the mask even if that pixel is not.
//
//------------
// Parameters:
// - Method: Diff on RGB, Chroma or Luma.
//
// - Threshold: How much difference between FG and SG is considered for masking.
//
// - FG Opacity: Typical multiplier when blending FG on BG.
//
// - Reveal: Show mask as white for debugging parameters.
//
// - Exclude Below: For each mask pixel, how many neighbors are also part of the mask?
//      If the number is equal or below this parameter, this mask pixel is removed.
//
// - Include Above: For each mask pixel, how many neighbors are also part of the mask?
//      If the number if equal or above this paraeter, this pixel is added to the mask.
//
//--------------
// Known Issues:
// The mask is computed by comparing the foreground clip with a reference image.
// Since the comparison is done by substracting colors and comparing to zero, there
// is a known effect where dark overlaping areas cannot be distinguished and are
// considered part of the mask. In other words, this only works if the foreground
// is properly constrasted compared to the reference image, exactly like one would
// avoid green colors on a greenscreen.
//
//--------------------------------------------------------------//
//
// License: MIT.
//
// Copyright 2018 Ralf <ralfoide at gmail>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
// PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
// FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
//--------------------------------------------------------------//
int _LwksEffectInfo
<
   string EffectGroup = "GenericPixelShader";
   string Description = "Ralf Blend Static Background";
   string Category    = "Mixes";
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
// Parameters
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
// Pixel Shaders
//--------------------------------------------------------------

// Reference: VS2005 shader language (HLSL)
// https://msdn.microsoft.com/en-us/library/windows/desktop/bb509615(v=vs.85).aspx
//
// Intrinsic functions:
// https://msdn.microsoft.com/en-us/library/windows/desktop/ff471376(v=vs.85).aspx
//
// LWKS doc:
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
// Techniques
//--------------------------------------------------------------

technique RGB {
    pass Pass1 <string Script = "RenderColorTarget0 = OutputPass1;"; > { 
        PixelShader = compile PROFILE ps_blend_rgb();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}

technique Colour {
    pass Pass1 <string Script = "RenderColorTarget0 = OutputPass1;"; > { 
        PixelShader = compile PROFILE ps_blend_chroma();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}

technique Luminosity {
    pass Pass1 <string Script = "RenderColorTarget0 = OutputPass1;"; > { 
        PixelShader = compile PROFILE ps_blend_luma();
    }
    
    pass Pass2 { 
        PixelShader = compile PROFILE ps_noise_redux_and_combine();
    }
}
