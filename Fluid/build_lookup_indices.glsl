#[compute]
#version 430

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    uint key=spatial_lookup.data[index].y;

    if(index==0)
    {
        start_indices.data[key]=index;
    }
    else if(spatial_lookup.data[index-1].y!=key)
    {
        start_indices.data[key]=index;
    }
}