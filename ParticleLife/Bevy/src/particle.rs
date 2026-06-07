use avian2d::prelude::*;
use bevy::{platform::collections::HashMap, prelude::*};
use bevy_prng::WyRand;
use bevy_rand::prelude::*;
use rand::RngExt;

#[derive(Component)]
pub struct Particle {
    pub kind: usize,
}

#[derive(Resource)]
pub struct InteractTable(pub HashMap<(usize, usize), f32>);

pub fn add_particles(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<ColorMaterial>>,
    mut rng: Single<&mut WyRand, With<GlobalRng>>,
) {
    for _ in 0..1000 {
        let radius = 1.0;
        let kind = rng.random_range(0..3);
        commands.spawn((
            Transform::from_xyz(
                rng.random_range(-100.0..100.0),
                rng.random_range(-100.0..100.0),
                0.0,
            ),
            Particle { kind },
            Mesh2d(meshes.add(Circle::new(radius))),
            MeshMaterial2d(materials.add(match kind {
                0 => Color::linear_rgb(1.0, 0.0, 0.0),
                1 => Color::linear_rgb(0.0, 1.0, 0.0),
                2 => Color::linear_rgb(0.0, 0.0, 1.0),
                _ => Color::linear_rgb(0.0, 0.0, 0.0),
            })),
            RigidBody::Dynamic,
            Collider::circle(radius),
            GravityScale(0.0),
            Mass(1.0),
            CenterOfMass::new(0.0, 0.0),
            LinearDamping(1.0),
        ));
    }
}

pub fn apply_interact_forces(
    interact_table: Res<InteractTable>,
    spatial_query: SpatialQuery,
    mut query: Query<(Entity, Forces, &Particle, &Transform)>,
) {
    let entities_data: Vec<_> = query
        .iter()
        .map(|(entity, _, particle, transform)| {
            (entity, particle.kind, transform.translation.truncate())
        })
        .collect();

    for (entity, kind, position) in entities_data {
        let filter = SpatialQueryFilter::from_excluded_entities(vec![entity]);

        let excludes =
            spatial_query.shape_intersections(&Collider::circle(10.0), position, 0.0, &filter);
        let includes =
            spatial_query.shape_intersections(&Collider::circle(100.0), position, 0.0, &filter);

        for entity in includes {
            if excludes.contains(&entity) {
                continue;
            }
            if let Ok((_, mut forces, particle, transform)) = query.get_mut(entity) {
                let direction = (transform.translation.truncate() - position).normalize();
                let key = if kind < particle.kind {
                    (kind, particle.kind)
                } else {
                    (particle.kind, kind)
                };
                if let Some(force) = interact_table.0.get(&key) {
                    forces.apply_force(direction * force);
                }
            }
        }
    }
}
