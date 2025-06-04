module main

import linklancien.playint { Appli, Bouton, attenuation }
import hexagons { Hexa_tile }
import os
import gg
import gx
import math.vec { Vec2 }

const bg_color = gg.Color{0, 0, 0, 255}
const font_path = os.resource_abs_path('FontMono.ttf')

struct App {
	playint.Opt
mut:
	// for this project:
	player_liste []string
	player_color []gx.Color

	playing bool
	// for the main menu

	// for placement turns
	in_placement_turns         bool
	players_units_to_place_ids [][]int

	// for waitingscreen
	in_waiting_screen bool

	// for the game
	player_id_turn int

	radius f32 = 30
	dec_x  int = 1
	dec_y  int = 1

	// important for save
	world_map           [][][]Hexa_tile
	players_units_liste [][]Units
	//

	in_selection bool
	pos_select_x int
	pos_select_y int
	troop_select Troops
	id_move_unit int = -1
}

struct Tile {
mut:
	color gx.Color = gx.Color{0, 125, 0, 255}
}

fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
		fullscreen:    false
		width:         100 * 8
		height:        100 * 6
		create_window: true
		window_title:  '-WAR OF ATTRITION-'
		user_data:     app
		bg_color:      bg_color
		init_fn:       on_init
		frame_fn:      on_frame
		event_fn:      on_event
		click_fn:      on_click
		resized_fn:    on_resized
		sample_count:  4
		font_path:     font_path
	)
	// setup before starting
	app.player_liste << ['RED', 'BLUE']
	app.player_color << [gx.Color{125, 0, 0, 255}, gx.Color{0, 0, 125, 255}]

	app.players_units_liste = [][]Units{len: app.player_liste.len, init: []Units{}}
	app.players_units_to_place_ids = [][]int{len: app.player_liste.len, init: []int{}}

	for p in 0 .. app.player_liste.len {
		for _ in 0 .. 10 {
			app.players_units_to_place_ids[p] << [app.players_units_liste[p].len]
			app.players_units_liste[p] << [
				Soldier{
					color: app.player_color[p]
				},
			]
		}
	}

	boutons_initialistation(mut app)

	app.world_map = [][][]Hexa_tile{len: 24, init: [][]Hexa_tile{len: 12, init: []Hexa_tile{len: 1, init: Hexa_tile(Tile{})}}}

	app.init()

	// run the window
	app.ctx.run()
}

fn on_init(mut app App) {
	// app.new_action(function, 'function_name', -1 or int(KeyCode. ))
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

	app.settings_render()
	app.boutons_draw()
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	app.on_event(e)
}

fn on_click(x f32, y f32, button gg.MouseButton, mut app App) {
	if app.in_placement_turns {
		check_placement(mut app)
	} else {
		check_unit_interaction(mut app)
	}

	app.check_boutons_options()
	app.boutons_check()
}

fn on_resized(e &gg.Event, mut app App) {
	size := gg.window_size()
	old_x := app.ctx.width
	old_y := app.ctx.height
	new_x := size.width
	new_y := size.height

	app.boutons_pos_resize(old_x, old_y, new_x, new_y)

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
	hexagons.draw_colored_map_x(app.ctx, app.dec_x, app.dec_y, app.radius, app.world_map,
		transparency)
	txt := app.player_liste[app.player_id_turn]
	playint.text_rect_render(app.ctx, app.text_cfg, 32, 32, true, true, txt, transparency)
	render_units(app, transparency)
	if app.in_placement_turns {
		txt_plac := 'PLACEMENT TURNS'
		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, 32, true, true,
			txt_plac, transparency)
		txt_nb := 'UNITS TO PLACE: ${app.players_units_to_place_ids[app.player_id_turn].len}'
		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 128, 32, true,
			true, txt_nb, transparency)
	}
}

fn check_placement(mut app App) {
	if app.playing && !app.in_waiting_screen {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if coo_x >= 0 && coo_y >= 0 {
			if app.players_units_to_place_ids[app.player_id_turn].len > 0
				&& app.world_map[coo_x][coo_y].len < 2 {
				app.world_map[coo_x][coo_y] << [
					Troops{
						team_nb: app.player_id_turn
						id:      app.players_units_to_place_ids[app.player_id_turn].pop()
					},
				]
			}
		}
		println(hexagons.path_to_hexa_x(0, 0, coo_x, coo_y, app.world_map.len + app.dec_x,
			app.world_map[0].len + app.dec_y))
	}
}

fn check_unit_interaction(mut app App) {
	if app.playing && !app.in_waiting_screen {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if coo_x >= 0 && coo_y >= 0 {
			if !app.in_selection && app.world_map[coo_x][coo_y].len > 1 {
				tempo := app.world_map[coo_x][coo_y].pop()
				if tempo is Troops {
					if tempo.team_nb == app.player_id_turn {
						app.troop_select = tempo

						app.pos_select_x = coo_x
						app.pos_select_y = coo_y

						app.in_selection = true
					} else {
						app.world_map[coo_x][coo_y] << [tempo]
					}
				} else {
					panic('${tempo} is not Troops')
				}
			} else if app.in_selection {
				if app.world_map[coo_x][coo_y].len < 2 {
					app.world_map[coo_x][coo_y] << [
						Troops{
							color:   app.troop_select.color
							team_nb: app.troop_select.team_nb
							id:      app.troop_select.id
						},
					]
				} else {
					app.world_map[app.pos_select_x][app.pos_select_y] << [
						Troops{
							color:   app.troop_select.color
							team_nb: app.troop_select.team_nb
							id:      app.troop_select.id
						},
					]
				}
				app.in_selection = false
			}
		}
	}
}

// BOUTONS:
// start
fn game_start(mut app Appli) {
	if mut app is App {
		app.playing = true
		app.in_waiting_screen = true
		app.in_placement_turns = true
		app.player_id_turn = app.player_liste.len - 1
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
			if app.in_placement_turns {
				app.in_placement_turns = false
			}
		} else {
			app.player_id_turn -= 1
		}
		if app.in_selection {
			app.world_map[app.pos_select_x][app.pos_select_y] << [
				Troops{
					color:   app.troop_select.color
					team_nb: app.troop_select.team_nb
					id:      app.troop_select.id
				},
			]
			app.in_selection = false
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

// APP INIT:
fn boutons_initialistation(mut app App) {
	app.boutons_list << [
		Bouton{
			text:           'START'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			function:       game_start
			is_visible:     start_is_visible
			is_actionnable: start_is_actionnable
		},
		Bouton{
			text:           'START TURN'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			function:       start_turn
			is_visible:     start_turn_is_visible
			is_actionnable: start_turn_is_actionnable
		},
		Bouton{
			text:           'END TURN'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height - 32
			}
			function:       end_turn
			is_visible:     end_turn_is_visible
			is_actionnable: end_turn_is_actionnable
		},
	]
}

// UNITS
fn render_units(app App, transparency u8) {
	for coo_x in 0 .. app.world_map.len {
		for coo_y in 0 .. app.world_map[coo_x].len {
			pos_x, pos_y := hexagons.coo_hexa_x_to_ortho(coo_x + app.dec_x, coo_y + app.dec_y)
			for mut troop in app.world_map[coo_x][coo_y][1..] {
				match mut troop {
					Troops {
						team := troop.team_nb
						unit_id := troop.id
						app.players_units_liste[team][unit_id].render(app.ctx, app.radius - 5,
							pos_x * app.radius, pos_y * app.radius, transparency)
					}
					else {}
				}
			}
		}
	}
	if app.in_selection {
		pos_x, pos_y := hexagons.coo_hexa_x_to_ortho(app.pos_select_x + app.dec_x,
			app.pos_select_y + app.dec_y)
		team := app.troop_select.team_nb
		unit_id := app.troop_select.id
		app.players_units_liste[team][unit_id].render(app.ctx, app.radius - 5, pos_x * app.radius,
			pos_y * app.radius, transparency - 100)
		app.players_units_liste[team][unit_id].select_render(app.ctx, unit_id, app, transparency)
	}
}

interface Units {
	render(gg.Context, f32, f32, f32, u8)
	select_render(gg.Context, int, App, u8)
mut:
	pv int
}

// for referencing in app.world_map
struct Troops {
mut:
	color   gx.Color = gx.Color{125, 125, 125, 255}
	team_nb int
	id      int
}

struct Soldier {
mut:
	pv         int      = 10
	mouvements int      = 30
	color      gx.Color = gx.Color{125, 125, 125, 255}
}

fn (sol Soldier) render(ctx gg.Context, radius f32, pos_x f32, pos_y f32, transparency u8) {
	ctx.draw_circle_filled(pos_x, pos_y, radius, attenuation(sol.color, transparency))
}

fn (sol Soldier) select_render(ctx gg.Context, id int, app App, transparency u8) {
	txt := 'UNIT Select: \nSoldier ${id} \nPv: ${sol.pv} \nMouvements: ${sol.mouvements}'

	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 64, app.ctx.height / 2,
		true, true, txt, transparency)
}
