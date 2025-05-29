module main

import linklancien.playint { Appli, Bouton }
import hexagons { Hexa_tile }
import os
import gg
import gx
import math.vec { Vec2 }

const bg_color = gg.Color{0, 0, 0, 255}
const font_path = os.resource_abs_path('FontMono.ttf')

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

	boutons_liste []Bouton

	// for this project:
	player_liste []string
	player_trun  int

	playing bool
	// for the main menu
	// for the game
	player_id_turn    int
	in_waiting_screen bool

	world_map [][][]Hexa_tile
}

struct Tile {
mut:
	color gx.Color = gx.Color{0, 125, 0, 255}
}

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		fullscreen:    false
		width:         100 * 6
		height:        100 * 6
		create_window: true
		window_title:  '-WAR OF ATTRITION-'
		user_data:     app
		bg_color:      bg_color
		init_fn:       on_init
		frame_fn:      on_frame
		event_fn:      on_event
		move_fn:       on_move
		click_fn:      on_click
		resized_fn:    on_resized
		sample_count:  4
		font_path:     font_path
	)
	// setup before starting
	app.player_liste << ['RED', 'BLUE']

	app.boutons_liste << [
		Bouton{
			text:           'START'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			fonction:       game_start
			is_visible:     start_is_visible
			is_actionnable: start_is_actionnable
		},
		Bouton{
			text:           'START TURN'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			fonction:       start_turn
			is_visible:     start_turn_is_visible
			is_actionnable: start_turn_is_actionnable
		},
		Bouton{
			text:           'END TURN'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height - 32
			}
			fonction:       end_turn
			is_visible:     end_turn_is_visible
			is_actionnable: end_turn_is_actionnable
		},
	]

	app.world_map = [][][]Hexa_tile{len: 24, init: [][]Hexa_tile{len: 12, init: []Hexa_tile{len: 1, init: Hexa_tile(Tile{})}}}

	app.opt.init()

	// run the window
	app.ctx.run()
}

fn on_init(mut app App) {
	// app.opt.new_action(fonction, 'fonction_name', -1 or int(KeyCode. ))
}

fn on_frame(mut app App) {
	app.ctx.begin()
	if app.playing {
		if app.in_waiting_screen {
			waiting_screen_render(app)
		} else {
			game_render(app)
		}
	} else {
		main_menu_render(app)
	}

	app.opt.settings_render(app)
	playint.boutons_draw(mut app)
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	playint.on_event(e, mut &app)
}

fn on_click(x f32, y f32, button gg.MouseButton, mut app App) {
	app.mouse_pos = Vec2[f32]{x, y}
	playint.check_boutons_options(mut app)
	playint.boutons_check(mut app)
}

fn on_move(x f32, y f32, mut app App) {
	app.mouse_pos = Vec2[f32]{x, y}
}

fn on_resized(e &gg.Event, mut app App) {
	size := gg.window_size()
	old_x := app.ctx.width
	old_y := app.ctx.height
	new_x := size.width
	new_y := size.height

	playint.boutons_pos_resize(mut app, old_x, old_y, new_x, new_y)

	app.ctx.width = size.width
	app.ctx.height = size.height
}

// main menu fn:
fn main_menu_render(app App) {
	// Main title
	mut transparency := u8(255)
	if app.changing_options {
		transparency = 150
	}
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
		true, true, 'War of Attrition', transparency)
	draw_players_names(app, transparency)
}

fn draw_players_names(app App, transparency u8) {
	for player_id in 0 .. app.player_liste.len {
		playint.text_rect_render(app.ctx, app.text_cfg, 0, player_id * app.text_cfg.size * 2,
			false, false, app.player_liste[player_id], transparency)
	}
}

// waiting screen
fn waiting_screen_render(app App) {
	mut transparency := u8(255)
	if app.changing_options {
		transparency = 150
	}
	txt := app.player_liste[app.player_id_turn]
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
		true, true, txt, transparency)
}

// games fn:
fn game_render(app App) {
	mut transparency := u8(255)
	if app.changing_options {
		transparency = 150
	}
	hexagons.draw_colored_map_x(app.ctx, 1, 1, f32(30), app.world_map, transparency)
}

// start
fn game_start(mut app Appli) {
	if mut app is App {
		app.playing = true
		app.in_waiting_screen = true
	}
}

fn start_is_visible(mut app Appli) bool {
	if mut app is App {
		return !app.playing
	}
	return false
}

fn start_is_actionnable(mut app Appli) bool {
	if mut app is App {
		return !app.playing && !app.changing_options
	}
	return false
}

// start turn
fn start_turn(mut app Appli) {
	if mut app is App {
		app.in_waiting_screen = false
	}
}

fn start_turn_is_visible(mut app Appli) bool {
	if mut app is App {
		return app.playing && app.in_waiting_screen
	}
	return false
}

fn start_turn_is_actionnable(mut app Appli) bool {
	if mut app is App {
		return app.playing && app.in_waiting_screen && !app.changing_options
	}
	return false
}

// end turn
fn end_turn(mut app Appli) {
	if mut app is App {
		if app.player_id_turn == 0 {
			app.player_id_turn = app.player_liste.len - 1
		} else {
			app.player_id_turn -= 1
		}
		app.in_waiting_screen = true
	}
}

fn end_turn_is_visible(mut app Appli) bool {
	if mut app is App {
		return app.playing && !app.in_waiting_screen
	}
	return false
}

fn end_turn_is_actionnable(mut app Appli) bool {
	if mut app is App {
		return app.playing && !app.in_waiting_screen && !app.changing_options
	}
	return false
}
