#[compute]
#version 430

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    uint radix_base=(1<<uint(params.radix_bits))-1;
    uint radix_shift=uint(params.radix_shift);
    uint bucket=(spatial_lookup.data[index].y>>radix_shift)&radix_base;
    atomicAdd(radix_count.data[bucket], 1);
}