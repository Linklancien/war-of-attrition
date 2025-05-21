module main

import playint
import gg
import gx
import math.vec { Vec2 }

const bg_color = gg.Color{0, 0, 0, 255}

struct App {
mut:
	// for playint:
	ctx &gg.Context = unsafe { nil }
	opt playint.Opt

	// Police
	text_cfg   gx.TextCfg
	bouton_cfg gx.TextCfg

	changing_options bool
	mouse_pos        Vec2[f32]

	// for this project:
	player_liste []string
	player_trun  int

	playing bool
	// for the main menu
	bouton_main_menu_liste []Bouton
	// for the game
}

struct Bouton {
mut:
	text     string
	pos      Vec2[f32]
	fonction fn (mut App) @[required]
}

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		fullscreen:    false
		width:         100 * 6
		height:        100 * 6
		create_window: true
		window_title:  '--'
		user_data:     app
		bg_color:      bg_color
		init_fn:       on_init
		frame_fn:      on_frame
		event_fn:      on_event
		move_fn:       on_move
		click_fn:      on_click
		resized_fn:    on_resized
		sample_count:  4
		font_path:     playint.font_path
	)
	// setup before starting
	app.player_liste << ['RED', 'BLUE']

	app.bouton_main_menu_liste << [
		Bouton{
			text:     'START'
			pos:      Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 30
			}
			fonction: game_start
		},
	]

	app.opt.init()

	// run the window
	app.ctx.run()
}

fn on_init(mut app App) {
	// app.opt.new_action(fonction, 'fonction_name', -1 or int(KeyCode. ))
}

fn on_frame(mut app App) {
	mut transparence := u8(255)
	if app.changing_options {
		transparence = u8(122)
	}
	app.ctx.begin()
	if app.playing {
	} else {
		draw_main_menu(app, transparence)
	}
	app.opt.settings_render(app, true)
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	playint.on_event(e, mut &app)
}

fn on_click(x f32, y f32, button gg.MouseButton, mut app App) {
	app.mouse_pos = Vec2[f32]{x, y}
	if app.changing_options {
		playint.check_boutons_options(mut app)
	} else if app.playing {
	} else {
		check_boutons_main_menu(mut app)
	}
}

fn on_move(x f32, y f32, mut app App) {
	app.mouse_pos = Vec2[f32]{x, y}
}

fn on_resized(e &gg.Event, mut app App) {
	size := gg.window_size()

	if app.changing_options {
	} else if app.playing {
	} else {
		for mut bouton in app.bouton_main_menu_liste {
			x := f32(bouton.pos.x * size.width / app.ctx.width)
			y := f32(bouton.pos.y * size.height / app.ctx.height)
			bouton.pos = Vec2[f32]{
				x: x
				y: y
			}
		}
	}

	app.ctx.width = size.width
	app.ctx.height = size.height
}

// main menu fn:
fn draw_main_menu(app App, transparence u8) {
	// Main title
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
		false, 'War of Attrition', transparence)
	draw_players_names(app, transparence)
	draw_boutons_main_menu(app, transparence)
}

fn draw_players_names(app App, transparence u8) {
	for player_id in 0 .. app.player_liste.len {
		playint.text_rect_render(app.ctx, app.text_cfg, 0, player_id * 30, true, app.player_liste[player_id],
			transparence)
	}
}

fn check_boutons_main_menu(mut app App) {
	for bouton in app.bouton_main_menu_liste {
		if playint.point_is_in_cirle(bouton.pos, 20, app.mouse_pos) {
			bouton.fonction(mut app)
		}
	}
}

fn draw_boutons_main_menu(app App, transparence u8) {
	for bouton in app.bouton_main_menu_liste {
		mut new_transparence := transparence
		if playint.point_is_in_cirle(bouton.pos, 20, app.mouse_pos) {
			new_transparence -= 75
		}
		playint.text_rect_render(app.ctx, app.text_cfg, bouton.pos.x, bouton.pos.y, false,
			bouton.text, new_transparence)
	}
}

// games fn:
fn game_start(mut app App) {
	app.playing = true
}
