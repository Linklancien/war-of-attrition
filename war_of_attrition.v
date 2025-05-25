module main

import linklancien.playint {Appli, Bouton}
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
			text:     'START'
			pos:      Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 30
			}
			fonction: game_start
			is_visible: start_is_visible
			is_actionnable: start_is_actionnable
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
	app.ctx.begin()
	app.opt.settings_render(app)
	playint.boutons_draw(mut app)
	main_menu_render(app)
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
	mut transparence := u8(255)
	if app.changing_options{
		transparence = 150
	}
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
		true, true, 'War of Attrition', transparence)
	app.ctx.draw_circle_filled(app.ctx.width / 2, app.ctx.height / 2,
					5, gx.red)
	app.ctx.draw_circle_filled(app.ctx.width / 2, app.ctx.height / 2 + 30,
					5, gx.red)
	draw_players_names(app, transparence)
}

fn draw_players_names(app App, transparence u8) {
	for player_id in 0 .. app.player_liste.len {
		playint.text_rect_render(app.ctx, app.text_cfg, 0, player_id * 40, false, false, app.player_liste[player_id],
			transparence)
	}
}

// games fn:
fn game_start(mut app Appli) {
	if mut app is App{
		app.playing = true
	}
}

fn start_is_visible (mut app Appli) bool{
	if mut app is App{
		return !app.playing
	}
	return false
}

fn start_is_actionnable (mut app Appli) bool{
	if mut app is App{
		return !app.playing && !app.changing_options
	}
	return false
}