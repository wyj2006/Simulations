#[compute]
#version 430

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    spatial_lookup.data[index]=radix_temp.data[index];
}