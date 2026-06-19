#[compute]
#version 430

layout(local_size_x=256,local_size_y=1,local_size_z=1) in;

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    positions.data[index]+=velocities.data[index]*params.dt;

    vec2 bound=vec2(params.width,params.height)/2-vec2(1,1)*params.particle_radius;

    if(abs(positions.data[index].x)>bound.x)
    {
        if(positions.data[index].x>=0)positions.data[index].x=bound.x;
        else positions.data[index].x=-bound.x;
        velocities.data[index].x*=-(1-params.collision_damp);
    }

    if(abs(positions.data[index].y)>bound.y)
    {
        if(positions.data[index].y>=0)positions.data[index].y=bound.y;
        else positions.data[index].y=-bound.y;
        velocities.data[index].y*=-(1-params.collision_damp);
    }
}