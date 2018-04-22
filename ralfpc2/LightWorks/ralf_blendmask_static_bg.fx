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

sampler FgSampler = sampler_state { Texture = <fg>; };
sampler BgSampler = sampler_state { Texture = <bg>; };
sampler SgSampler = sampler_state { Texture = <sg>; };

//--------------------------------------------------------------//
// Define parameters here.
//
// The Lightworks application will automatically generate
// sliders/controls for all parameters which do not start
// with a a leading '_' character
//--------------------------------------------------------------//

float RgbThreshold
<
   string Description = "RGB Threshold";
   float MinVal = 0.00;
   float MaxVal = 1.00;
> = 0.05;

float Opacity
<
   string Description = "Fg Opacity";
   float MinVal = 0.00;
   float MaxVal = 1.00;
> = 1.0;

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


float4 blend_main( float2 xy1 : TEXCOORD1, float2 xy2 : TEXCOORD2, float2 xy3 : TEXCOORD3 ) : COLOR
{
   float4 fg = tex2D( FgSampler, xy1 );
   float4 bg = tex2D( BgSampler, xy2 );
   float4 sg = tex2D( SgSampler, xy3 );
   
   float4 ret = abs(fg - sg);
   float threshold = ( ret.r + ret.g + ret.b ) / 3.0;
   
   float alpha = (threshold < RgbThreshold ? 0.0 : 1.0 );

   ret = lerp( bg, fg, alpha * Opacity );
   ret.a = 1.0;

   return ret;
}


//--------------------------------------------------------------
// Technique
//
// Specifies the order of passes (we only have a single pass, so
// there's not much to do)
//--------------------------------------------------------------
technique StaticBgFxTechnique
{
   pass SinglePass
   {
      PixelShader = compile PROFILE blend_main();
   }
}

