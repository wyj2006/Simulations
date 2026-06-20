#[compute]
#version 430

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    ivec2 cell_coord=position_to_cell_coord(positions.data[index]);
    uint key=hash_cell(cell_coord);
    spatial_lookup.data[index]=ivec2(index,key);
    start_indices.data[index]=0xffffffff;
}