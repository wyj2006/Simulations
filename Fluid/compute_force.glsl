#[compute]
#version 430

layout(local_size_x=256,local_size_y=1,local_size_z=1) in;

#include "shader_common.glsl"

void main()
{
    uint index=gl_GlobalInvocationID.x;
    if(index>=params.particle_num)return;

    vec2 force=vec2(0,0);

    force+=external_force.data[index];
    force+=vec2(0,1)*params.gravity*densities.data[index];

    vec2 velocity0=velocities.data[index];
    float density0=densities.data[index];
    float pressure0=density_to_pressure(density0);
    vec2 sample_point=positions.data[index];

    ivec2 center=position_to_cell_coord(sample_point);
    for(int dx=-1;dx<=1;dx++)
    {
        for(int dy=-1;dy<=1;dy++)
        {
            uint key=hash_cell(center+ivec2(dx,dy));
            uint start=start_indices.data[key];
            for(uint i=start;i<params.particle_num;i++)
            {
                if(spatial_lookup.data[i].y!=key)break;
                vec2 dest=sample_point-positions.data[spatial_lookup.data[i].x];
                if(length(dest)>params.smooth_radius)continue;

                int k=spatial_lookup.data[i].x;
                float density=densities.data[k];
                float shared_pressure=(density_to_pressure(density)+pressure0)/2;
                force+=-shared_pressure*params.mass/density*grad_w_spiy(dest);
                force+=params.viscosity*(velocities.data[k]-velocity0)*params.mass/density*laplacian_w_viscosity(length(dest));
            }
        }
    }

    velocities.data[index]+=force/densities.data[index]*params.dt;
}