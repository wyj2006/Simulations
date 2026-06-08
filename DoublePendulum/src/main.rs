use bevy::{
    color::palettes::css::{BLACK, BLUE, RED, WHITE},
    input_focus::InputFocus,
    prelude::*,
};
use clap::Parser;
use rand::{prelude::*, rng};
use std::f32::consts::PI;

#[derive(Parser)]
pub struct Command {
    #[arg(long, default_value_t = 9.8)]
    pub gravity: f32,
    #[arg(long, default_value_t = 200.0)]
    pub length1: f32,
    #[arg(long, default_value_t = 200.0)]
    pub length2: f32,
    #[arg(long, default_value_t = 1.0)]
    pub mass1: f32,
    #[arg(long, default_value_t = 1.0)]
    pub mass2: f32,
    #[arg(long, default_value_t = 100000)]
    pub max_track_len: usize,
}

#[derive(Resource)]
pub struct Track {
    pub points: Vec<Vec2>,
    pub max_len: usize,
}

#[derive(Resource)]
pub struct Solver {
    pub gravity: f32,
    pub start_pos: Vec2,
    pub length: [f32; 2],
    pub theta: [f32; 2],
    //theta的一阶导
    pub theta_d: [f32; 2],
    pub mass: [f32; 2],
}

pub fn draw_pendulum(solver: Res<Solver>, mut track: ResMut<Track>, mut gizmos: Gizmos) {
    let Solver {
        start_pos,
        length,
        theta,
        ..
    } = solver.as_ref();

    let end_pos = vec2(
        start_pos.x + length[0] * theta[0].sin(),
        start_pos.y - length[0] * theta[0].cos(),
    );
    gizmos.line_2d(*start_pos, end_pos, BLACK);
    gizmos.circle_2d(Isometry2d::from_translation(end_pos), 10.0, RED);

    let start_pos = end_pos;
    let end_pos = vec2(
        start_pos.x + length[1] * theta[1].sin(),
        start_pos.y - length[1] * theta[1].cos(),
    );
    gizmos.line_2d(start_pos, end_pos, BLACK);
    gizmos.circle_2d(Isometry2d::from_translation(end_pos), 10.0, RED);

    track.points.push(end_pos);
    if track.points.len() >= track.max_len {
        track.points.remove(0);
    }
    for pos in &track.points {
        gizmos.circle_2d(Isometry2d::from_translation(*pos), 1.0, BLUE);
    }
}

pub fn step(mut solver: ResMut<Solver>, time: Res<Time>) {
    let Solver {
        gravity,
        length,
        theta,
        theta_d,
        mass,
        ..
    } = solver.as_mut();
    let g = *gravity;

    let theta_dd1 = (-g * (2.0 * mass[0] + mass[1]) * theta[0].sin()
        - mass[1] * g * (theta[0] - 2.0 * theta[1]).sin()
        - 2.0
            * (theta[0] - theta[1]).sin()
            * mass[1]
            * (theta_d[1].powi(2) * length[1]
                + theta_d[0].powi(2) * length[0] * (theta[0] - theta[1]).cos()))
        / (length[0]
            * (2.0 * mass[0] + mass[1] - mass[1] * (2.0 * theta[0] - 2.0 * theta[1]).cos()));
    let theta_dd2 = (2.0
        * (theta[0] - theta[1]).sin()
        * (theta_d[0].powi(2) * length[0] * (mass[0] + mass[1])
            + g * (mass[0] + mass[1]) * theta[0].cos()
            + theta_d[1].powi(2) * length[1] * mass[1] * (theta[0] - theta[1]).cos()))
        / (length[1]
            * (2.0 * mass[0] + mass[1] - mass[1] * (2.0 * theta[0] - 2.0 * theta[1]).cos()));

    let dt = time.delta_secs();

    theta_d[0] += theta_dd1 * dt;
    theta_d[1] += theta_dd2 * dt;

    theta[0] += theta_d[0] * dt;
    theta[1] += theta_d[1] * dt;
}

fn button_system(
    mut solver: ResMut<Solver>,
    mut track: ResMut<Track>,
    mut query: Query<&Interaction, (With<Button>, Changed<Interaction>)>,
) {
    for interaction in &mut query {
        match *interaction {
            Interaction::Pressed => {
                let mut rng = rng();
                solver.theta = [
                    rng.random_range(-PI / 2.0..=PI / 2.0),
                    rng.random_range(-PI / 2.0..=PI / 2.0),
                ];
                solver.theta_d = [0.0, 0.0];
                track.points.clear();
            }
            _ => {}
        }
    }
}

pub fn setup(mut commands: Commands) {
    commands.spawn(Camera2d);
    commands.spawn((
        Node { ..default() },
        children![(
            Button,
            Node {
                width: px(60),
                height: px(30),
                border: UiRect::all(px(1)),
                justify_content: JustifyContent::Center,
                align_items: AlignItems::Center,
                ..default()
            },
            BorderColor::all(Color::BLACK),
            BackgroundColor(Color::WHITE),
            children![(Text::new("Reset"), TextColor(Color::BLACK),)]
        )],
    ));
}

fn main() {
    let command = Command::parse();
    let mut rng = rng();

    App::new()
        .add_plugins(DefaultPlugins.set(WindowPlugin {
            primary_window: Some(Window {
                resolution: (1000, 618).into(),
                ..default()
            }),
            ..default()
        }))
        .insert_resource(Time::<Fixed>::from_hz(60.0))
        .insert_resource(ClearColor(WHITE.into()))
        .insert_resource(Solver {
            gravity: command.gravity,
            start_pos: vec2(0.0, 309.0),
            length: [command.length1, command.length2],
            theta: [
                rng.random_range(-PI / 2.0..=PI / 2.0),
                rng.random_range(-PI / 2.0..=PI / 2.0),
            ],
            theta_d: [0.0, 0.0],
            mass: [command.mass1, command.mass1],
        })
        .insert_resource(Track {
            points: vec![],
            max_len: command.max_track_len,
        })
        .init_resource::<InputFocus>()
        .add_systems(Startup, setup)
        .add_systems(Update, draw_pendulum)
        .add_systems(Update, step)
        .add_systems(Update, button_system)
        .run();
}
