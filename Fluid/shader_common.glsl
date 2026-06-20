#define PI 3.14159265358979323846

layout(local_size_x=256,local_size_y=1,local_size_z=1) in;

layout(set=0,binding=0) restrict buffer Parameters{
    float particle_num;
    float smooth_radius;
    float mass;
    float gravity;
    float width;
    float height;
    float pressure_multiplier;
    float viscosity;
    float target_density;
    float particle_radius;
    float collision_damp;
    float dt;
    float radix_bits;
    float radix_shift;
}params;

layout(set=0,binding=1) restrict buffer PositionBuffer{
    vec2 data[];
}positions;

layout(set=0,binding=2) restrict buffer VelocityBuffer{
    vec2 data[];
}velocities;

layout(set=0,binding=3) restrict buffer DensityBuffer{
    float data[];
}densities;

layout(set=0,binding=4) restrict buffer ExternalForceBuffer{
    vec2 data[];
}external_force;

layout(set=0,binding=5) restrict buffer SpatialLookupBuffer{
    ivec2 data[];
}spatial_lookup;

layout(set=0,binding=6) restrict buffer StartIndicesBuffer{
    uint data[];
}start_indices;

layout(set=0,binding=7) restrict buffer RadixCountBuffer{
    uint data[];
}radix_count;

layout(set=0,binding=8) restrict buffer RadixTempBuffer{
    ivec2 data[];
}radix_temp;

layout(set=0,binding=9) restrict buffer RadixOffsetBuffer{
    uint data[];
}radix_offset;

uint hash_cell(ivec2 coord)
{
    return ((coord.x*15823+coord.y*9737333)&0x7fffffff)%uint(params.particle_num);
}

ivec2 position_to_cell_coord(vec2 point)
{
    return ivec2(int(point.x/params.smooth_radius),int(point.y/params.smooth_radius));
}

float w_poly6(float dest)
{
    float radius=params.smooth_radius;
    if(dest>radius)return 0;
    float k_poly6=4/(PI*pow(radius,8));
    return k_poly6*pow(radius*radius-dest*dest,3);
}

vec2 grad_w_spiy(vec2 dest)
{
    float radius=params.smooth_radius;
    float dest_len=length(dest);
    if(dest_len>radius || dest_len<1e-6)return vec2(0,0);
    return -dest*10/(PI*pow(radius,5)*dest_len)*(radius-dest_len)*(radius-dest_len);
}

float laplacian_w_viscosity(float dest)
{
    float radius=params.smooth_radius;
    if(dest>radius || dest<1e-6)return 0;
    return 45/(PI*pow(radius,6))*(radius-dest);
}

float density_to_pressure(float density)
{
    return (density-params.target_density)*params.pressure_multiplier;
}