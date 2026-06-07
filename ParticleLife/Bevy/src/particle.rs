use std::ops::Range;

use avian2d::prelude::*;
use bevy::{platform::collections::HashMap, prelude::*};
use bevy_prng::WyRand;
use bevy_rand::prelude::*;
use rand::RngExt;
use rayon::prelude::*;
use rustc_hash::FxHashMap;

const CELL_SIZE: f32 = 110.0;
const X_LIMIT: Range<f32> = -500.0..500.0;
const Y_LIMIT: Range<f32> = -500.0..500.0;

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
    for _ in 0..40000 {
        let radius = 1.0;
        let kind = rng.random_range(0..6);
        commands.spawn((
            Transform::from_xyz(rng.random_range(X_LIMIT), rng.random_range(Y_LIMIT), 0.0),
            Particle { kind },
            Mesh2d(meshes.add(Circle::new(radius))),
            MeshMaterial2d(materials.add(match kind {
                0 => Color::linear_rgb(1.0, 0.0, 0.0),
                1 => Color::linear_rgb(0.0, 0.0, 1.0),
                2 => Color::linear_rgb(1.0, 0.0, 1.0),
                3 => Color::linear_rgb(1.0, 1.0, 0.0),
                4 => Color::linear_rgb(0.0, 1.0, 1.0),
                5 => Color::linear_rgb(0.0, 0.0, 0.0),
                _ => Color::linear_rgb(1.0, 1.0, 1.0),
            })),
            LinearVelocity::ZERO,
            LinearDamping(0.1),
            Mass(1.0),
        ));
    }
}

pub fn update_postition(
    time: Res<Time>,
    query: Query<(&mut Transform, &mut LinearVelocity, &LinearDamping)>,
) {
    let dt = time.delta_secs();
    for (mut transform, mut velocity, damp) in query {
        transform.translation += velocity.0.extend(0.0) * dt;
        velocity.0 *= 1.0 - damp.0;
    }
}

pub fn apply_interact_forces(
    time: Res<Time>,
    interact_table: Res<InteractTable>,
    mut query: Query<(Entity, &Particle, &Transform, &mut LinearVelocity, &Mass)>,
) {
    let mut particles: Vec<_> = query.iter_mut().collect();

    let mut grid = FxHashMap::default();
    for (i, &(_, _, transform, _, _)) in particles.iter().enumerate() {
        let pos = transform.translation.truncate();
        let gx = (pos.x / CELL_SIZE).floor() as i32;
        let gy = (pos.y / CELL_SIZE).floor() as i32;
        grid.entry((gx, gy)).or_insert(vec![]).push(i);
    }

    let accelerations: Vec<Vec2> = (0..particles.len())
        .into_par_iter()
        .map(|i| {
            let pos_i = particles[i].2.translation.truncate();
            let kind_i = particles[i].1.kind;
            let mass_i = particles[i].4.0;

            let gx = (pos_i.x / CELL_SIZE).floor() as i32;
            let gy = (pos_i.y / CELL_SIZE).floor() as i32;
            let mut total_a = Vec2::ZERO;

            for dx in -1..=1 {
                for dy in -1..=1 {
                    let key = (gx + dx, gy + dy);
                    if let Some(cell) = grid.get(&key) {
                        for &j in cell {
                            if i == j {
                                continue;
                            }
                            let pos_j = particles[j].2.translation.truncate();
                            let kind_j = particles[j].1.kind;

                            let distance = pos_i.distance(pos_j);
                            if !(20.0 < distance && distance < 100.0) {
                                continue;
                            }

                            let direction = (pos_j - pos_i).normalize();
                            let key = if kind_i < kind_j {
                                (kind_i, kind_j)
                            } else {
                                (kind_j, kind_i)
                            };
                            if let Some(force) = interact_table.0.get(&key) {
                                total_a += direction * force / mass_i;
                            }
                        }
                    }
                }
            }
            total_a
        })
        .collect();

    let dt = time.delta_secs();
    for (i, a) in accelerations.iter().enumerate() {
        particles.get_mut(i).unwrap().3.0 += a * dt;
    }
}
