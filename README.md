# Ralf's Video Plugins


## DaVinci Resolve/Fusion

### Ralf Cam Car Rod Removal (Fuse)

This Fuse detects and removes the gray rod from a camera car attached to HO model trains.


Fuse: [`RalfCamCarRodRemoval.fuse`](./fusion/fuses/RalfCamCarRodRemoval.fuse)

<p align="center">
<img title="Example of RalfCamCarRodRemoval render" src="./fusion/images/rod_fuse_result.jpg" >
</p>

Description: [RalfCamCarRodRemoval.md](./fusion/fuses/RalfCamCarRodRemoval.md) for full details.

---

### Ralf Delta Mask (Fuse)

This Fuse is a mix between a Delta Keyer, a Difference Keyer, and a Merge node.
It's a direct recreation in Fusion of the LightWorks FX Shader I wrote years ago (see below).

Fuse: [`RalfDeltaMask.fuse`](./fusion/fuses/RalfDeltaMask.fuse)

<p align="center">
<img title="Example of Ralf Delta Mask render" src="./fusion/images/tbd.jpg" >
</p>

Description: [RalfDeltaMask.md](./fusion/fuses/RalfDeltaMask.md) for full details.

---

## LightWorks

The following FX shader was written for LightWorks 12.0.

### Ralf Delta Mas Blend (FX Shader)

This FX Shader is a 1-pass delta keyer combined with a mask & overlay merge operation.

FX Shader: [`ralf_delta_mask_blend.fx`](./lightworks/fx_shaders/ralf_delta_mask_blend.fx)

<p align="center">
<img title="Example of Ralf Delta Mask render" src="./lightworks/fx_shaders/blendmask_explanation.jpg" width="75%" >
</p>

Description: [blendmask_explanation.jpg](./lightworks/fx_shaders/blendmask_explanation.jpg) for full details.


~~