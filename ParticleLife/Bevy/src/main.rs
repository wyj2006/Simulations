pub mod particle;

use crate::particle::{InteractTable, add_particles, apply_interact_forces, update_postition};
use bevy::camera_controller::pan_camera::{PanCamera, PanCameraPlugin};
use bevy::input::mouse::MouseMotion;
use bevy::platform::collections::HashMap;
use bevy::prelude::*;
use bevy_prng::WyRand;
use bevy_rand::prelude::*;

pub fn add_camera(mut commands: Commands) {
    commands.spawn((Camera2d, PanCamera::default()));
}

pub fn camera_drag(
    mouse_input: Res<ButtonInput<MouseButton>>,
    mut mouse_motion: MessageReader<MouseMotion>,
    mut query: Query<(&mut Transform, &PanCamera)>,
) {
    let Ok((mut transform, controller)) = query.single_mut() else {
        return;
    };

    if !controller.enabled {
        return;
    }

    if !mouse_input.pressed(MouseButton::Left) {
        mouse_motion.clear();
        return;
    }

    for motion in mouse_motion.read() {
        let delta = vec2(-1.0, 1.0) * motion.delta * controller.zoom_factor;

        transform.translation.x += delta.x;
        transform.translation.y += delta.y;
    }
}

fn main() {
    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                resolution: (1000, 618).into(),
                ..default()
            }),
            ..default()
        }))
        .add_plugins(PanCameraPlugin)
        .add_plugins(EntropyPlugin::<WyRand>::default())
        .insert_resource(InteractTable(HashMap::from([
            ((0, 0), 1.0),
            ((0, 1), -1.0),
            ((0, 2), 1.0),
            ((0, 3), -1.0),
            ((0, 4), 1.0),
            ((0, 5), -1.0),
            ((1, 1), 1.0),
            ((1, 2), -1.0),
            ((1, 3), 1.0),
            ((1, 4), -1.0),
            ((1, 5), 1.0),
            ((2, 2), -1.0),
            ((2, 3), 1.0),
            ((2, 4), -1.0),
            ((2, 5), 1.0),
            ((3, 3), -1.0),
            ((3, 4), 1.0),
            ((3, 5), -1.0),
            ((4, 4), 1.0),
            ((4, 5), -1.0),
            ((5, 5), 1.0),
        ])))
        .insert_resource(ClearColor(Color::srgb(1.0, 1.0, 1.0)))
        .add_systems(Startup, add_camera)
        .add_systems(Update, camera_drag)
        .add_systems(Startup, add_particles)
        .add_systems(Update, update_postition)
        .add_systems(Update, apply_interact_forces)
        .run();
}
