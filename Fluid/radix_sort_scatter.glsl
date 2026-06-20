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

    uint offset=0;
    for(uint i=0;i<index;i++)
    {
        if(bucket==((spatial_lookup.data[i].y>>radix_shift)&radix_base))
            offset++;
    }
    radix_offset.data[index]=offset;

    uint pos=radix_count.data[bucket]+radix_offset.data[index];
    radix_temp.data[pos]=spatial_lookup.data[index];
}