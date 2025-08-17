module main

import linklancien.playint { Appli, Button, attenuation }
import hexagons { Hexa_tile }
import os
import gg { KeyCode }
import math.vec { Vec2 }
import json

const bg_color = gg.Color{0, 0, 0, 255}
const font_path = os.resource_abs_path('FontMono.ttf')

type Effect_fn = fn (mut Units, int) int

struct App {
	playint.Opt
mut:
	// for this project:
	player_liste []string
	player_color []gg.Color

	playing bool

	map_unit_exist map[string]Units
	map_capa_exist map[string]Capas
	map_image      map[string]gg.Image

	// for placement turns:
	placement_boundaries [][]int

	// format: [x, max_x, y max_y]
	in_placement_turns         bool
	players_units_to_place_ids [][]int

	// for waitingscreen
	in_waiting_screen bool

	// for the game
	effects_functions []Effect_fn
	player_id_turn    int

	radius f32 = 30
	dec_x  int = 2
	dec_y  int = 2

	// important for save
	world_map           [][][]Hexa_tile
	players_units_liste [][]Units

	//
	in_selection   bool
	pos_select_x   int
	pos_select_y   int
	troop_select   Troops
	id_capa_select int = -1
}

struct Tile {
mut:
	color gg.Color = gg.Color{0, 125, 0, 255}
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
	app.player_color << [gg.Color{125, 0, 0, 255}, gg.Color{0, 0, 125, 255}]

	app.players_units_liste = [][]Units{len: app.player_liste.len, init: []Units{}}
	app.players_units_to_place_ids = [][]int{len: app.player_liste.len, init: []int{}}

	app.capas_load()
	app.units_load()
	app.images_load()

	for p in 0 .. app.player_liste.len {
		list_unit := ['Healer', 'Tank', 'Grenade Soldier', 'Toxic Soldier']
		for next in list_unit {
			app.players_units_to_place_ids[p] << [app.players_units_liste[p].len]
			app.players_units_liste[p] << [
				app.map_unit_exist[next],
			]
			app.players_units_liste[p][app.players_units_liste[p].len - 1].color = app.player_color[p]
		}
	}
	app.world_map = [][][]Hexa_tile{len: 24, init: [][]Hexa_tile{len: 12, init: []Hexa_tile{len: 1, init: Hexa_tile(Tile{})}}}
	app.placement_boundaries = [[0, 5, 0, app.world_map[0].len],
		[app.world_map.len - 5, app.world_map.len, 0, app.world_map[0].len]]

	app.init()

	// run the window
	app.ctx.run()
}

fn on_init(mut app App) {
	app.buttons_initialistation()
	app.actions_initialistation()
	app.effects_initialistation()
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
	app.buttons_draw(mut app)
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	app.on_event(e, mut app)
}

fn on_click(x f32, y f32, button gg.MouseButton, mut app App) {
	if app.in_placement_turns {
		app.check_placement()
	} else {
		app.check_unit_interaction()
	}

	app.check_buttons_options()
	app.buttons_check(mut app)
}

fn on_resized(e &gg.Event, mut app App) {
	size := gg.window_size()
	old_x := app.ctx.width
	old_y := app.ctx.height
	new_x := size.width
	new_y := size.height

	app.buttons_pos_resize(old_x, old_y, new_x, new_y)

	app.ctx.width = size.width
	app.ctx.height = size.height
}

// APP INIT: //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
fn (mut app App) capas_load() {
	entries := os.ls(os.join_path('capas')) or { [] }

	// load capas
	for entry in entries {
		path := os.join_path('capas', entry)
		if os.is_dir(path) {
			println('dir: ${entry}')
		} else {
			temp_capas := (os.read_file(path) or { panic('No temp_capas to load') })
			capa := json.decode(Capas, temp_capas) or {
				panic('Failed to decode json, path: ${path}, error: ${err}')
			}
			app.map_capa_exist[capa.name] = capa
		}
	}
}

fn (mut app App) units_load() {
	entries := os.ls(os.join_path('units')) or { [] }

	// load units
	for entry in entries {
		path := os.join_path('units', entry)
		if os.is_dir(path) {
			println('dir: ${entry}')
		} else {
			temp_units := (os.read_file(path) or { panic('No temp_units to load') })
			unit := json.decode(Units, temp_units) or {
				panic('Failed to decode json, error: ${err}')
			}

			app.map_unit_exist[unit.name] = unit
		}
	}
}

fn (mut app App) images_load() {
	entries := os.ls(os.join_path('images')) or { [] }

	// load units
	for entry in entries {
		path := os.join_path('images', entry)
		if os.is_dir(path) {
			println('dir: ${entry}')
		} else {
			image := app.ctx.create_image(path) or {
				app.ctx.create_image('images/error.png') or { panic('No image') }
			}
			app.map_image[entry#[..-4]] = image
		}
	}
}

fn (mut app App) buttons_initialistation() {
	app.buttons_list << [
		Button{
			text:           'START'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			function:       game_start
			is_visible:     start_is_visible
			is_actionnable: start_is_actionnable
		},
		Button{
			text:           'START TURN'
			pos:            Vec2[f32]{
				x: app.ctx.width / 2
				y: app.ctx.height / 2 + 32
			}
			function:       start_turn
			is_visible:     start_turn_is_visible
			is_actionnable: start_turn_is_actionnable
		},
		Button{
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

fn (mut app App) actions_initialistation() {
	// app.new_action(function, 'function_name', -1 or int(KeyCode. ))
	app.new_action(next_state, 'game start', int(KeyCode.enter))

	name := ['camera up', 'camera down', 'camera right', 'camera left']
	mvt := [[0, 2], [0, -2], [-2, 0], [2, 0]]
	key := [int(KeyCode.up), int(KeyCode.down), int(KeyCode.right), int(KeyCode.left)]
	for i in 0 .. 4 {
		move_x := mvt[i][0]
		move_y := mvt[i][1]
		app.new_action(fn [move_x, move_y] (mut app Appli) {
			cam_move(mut app, move_x, move_y)
		}, name[i], key[i])
	}

	mut capa_name := []string{len: 10, init: 'capa ${index} shortcut'}
	capa_keys := [int(KeyCode._0), int(KeyCode._1), int(KeyCode._2), int(KeyCode._3), int(KeyCode._4),
		int(KeyCode._5), int(KeyCode._6), int(KeyCode._7), int(KeyCode._8), int(KeyCode._9)]
	for i in 0 .. 10 {
		app.new_action(fn [i] (mut app Appli) {
			capa_short_cut(mut app, i)
		}, capa_name[i], capa_keys[i])
	}
}

// main menu fn: //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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

// game fn: ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
fn game_render(app App) {
	mut transparency := u8(255)
	if app.changing_options {
		transparency = 150
	}
	mut path := [][]int{}
	if app.in_selection {
		if app.id_capa_select == -1 {
			mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
				app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x,
				app.world_map[0].len + app.dec_y)

			coo_x -= app.dec_x
			coo_y -= app.dec_y
			distance := hexagons.distance_hexa_x(app.pos_select_x, app.pos_select_y, coo_x,
				coo_y)
			mvt := app.players_units_liste[app.player_id_turn][app.troop_select.id].mouvements
			if coo_x != -1 && coo_y != -1 && distance <= mvt {
				path = hexagons.path_to_hexa_x(app.pos_select_x, app.pos_select_y, coo_x,
					coo_y, app.world_map.len + app.dec_x, app.world_map[0].len + app.dec_y)
			}
		} else {
			key := app.players_units_liste[app.player_id_turn][app.troop_select.id].capas[app.id_capa_select]
			path = app.map_capa_exist[key].previsualisation(app)
		}
	}
	if app.in_placement_turns {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if app.check_placement_possible(coo_x, coo_y) {
			path << [coo_x, coo_y]
		}
	}

	// map
	hexagons.draw_colored_map_x(app.ctx, app.dec_x, app.dec_y, app.radius, app.world_map,
		path, transparency)

	// player turn
	txt := app.player_liste[app.player_id_turn]
	playint.text_rect_render(app.ctx, app.text_cfg, 32, 32, true, true, txt, transparency)

	// units
	app.units_render(transparency)
	app.pv_render(transparency)

	// placements turns
	if app.in_placement_turns {
		txt_plac := 'PLACEMENT TURNS
		boundaries: ${app.placement_boundaries[app.player_id_turn]}'

		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, 32, true, true,
			txt_plac, transparency)

		if path.len == 0 {
			playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
				true, true, 'OUT OF BOUNDS', transparency)
		}

		team := app.player_id_turn
		len := app.players_units_to_place_ids[team].len
		txt_nb := 'UNITS TO PLACE: ${len}'
		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 128, 32, true,
			true, txt_nb, transparency)

		if len > 0 {
			unit_id := app.players_units_to_place_ids[team][len - 1]
			app.players_units_liste[team][unit_id].stats_render(app.ctx, unit_id, app,
				transparency)
		}
	}
}

fn (app App) pv_render(transparency u8) {
	mut txt_pv := ''
	for id, unit in app.players_units_liste[app.player_id_turn] {
		if id == 0 {
			txt_pv += '${id}: ${unit.pv}/${unit.pv_max}'
		} else {
			txt_pv += '\n${id}: ${unit.pv}/${unit.pv_max}'
		}
	}
	playint.text_rect_render(app.ctx, app.text_cfg, 48, app.ctx.height / 2, true, true,
		txt_pv, transparency - 40)
}

fn (mut app App) check_placement() {
	if app.playing && !app.in_waiting_screen && !app.buttons_list[2].check(mut app) {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if coo_x >= 0 && coo_y >= 0 && app.check_placement_possible(coo_x, coo_y) {
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
	}
}

fn (app App) check_placement_possible(coo_x int, coo_y int) bool {
	boundaries := app.placement_boundaries[app.player_id_turn]
	return boundaries[0] <= coo_x && coo_x < boundaries[1] && boundaries[2] <= coo_y
		&& coo_y < boundaries[3]
}

fn (mut app App) check_unit_interaction() {
	if app.playing && !app.in_waiting_screen {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if coo_x >= 0 && coo_y >= 0 {
			app.units_interactions(coo_x, coo_y)
		}
	}
}

fn (mut app App) units_interactions(coo_x int, coo_y int) {
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
		if app.id_capa_select == -1 {
			unit_move(mut app, coo_x, coo_y)
		} else {
			if !app.players_units_liste[app.player_id_turn][app.troop_select.id].capa_used {
				app.players_units_liste[app.player_id_turn][app.troop_select.id].capa_used = true
				key := app.players_units_liste[app.player_id_turn][app.troop_select.id].capas[app.id_capa_select]
				app.map_capa_exist[key].use(mut app)
				app.world_map[app.pos_select_x][app.pos_select_y] << [
					Troops{
						color:   app.troop_select.color
						team_nb: app.troop_select.team_nb
						id:      app.troop_select.id
					},
				]
				app.check_death()
			}
		}

		app.id_capa_select = -1
		app.in_selection = false
	}
}

fn unit_move(mut app App, coo_x int, coo_y int) {
	mvt := app.players_units_liste[app.player_id_turn][app.troop_select.id].mouvements
	distance := hexagons.distance_hexa_x(app.pos_select_x, app.pos_select_y, coo_x, coo_y)
	if app.world_map[coo_x][coo_y].len < 2 && distance <= mvt {
		app.world_map[coo_x][coo_y] << [
			Troops{
				color:   app.troop_select.color
				team_nb: app.troop_select.team_nb
				id:      app.troop_select.id
			},
		]
		app.players_units_liste[app.player_id_turn][app.troop_select.id].mouvements -= distance
	} else {
		app.world_map[app.pos_select_x][app.pos_select_y] << [
			Troops{
				color:   app.troop_select.color
				team_nb: app.troop_select.team_nb
				id:      app.troop_select.id
			},
		]
	}
}

fn (mut app App) check_death() {
	for x in 0 .. app.world_map.len {
		for y in 0 .. app.world_map[0].len {
			mut correctif_id := 0
			for id in 1 .. app.world_map[x][y].len {
				troop := app.world_map[x][y][id - correctif_id]
				if troop is Troops {
					team := troop.team_nb
					index := troop.id
					if app.players_units_liste[team][index].pv <= 0 {
						app.world_map[x][y].delete(id - correctif_id)
						correctif_id += 1
					}
				}
			}
		}
	}
}

// actions for the player
fn cam_move(mut app Appli, move_x int, move_y int) {
	if mut app is App {
		if !app.changing_options {
			app.dec_x += move_x
			app.dec_y += move_y
		}
	}
}

fn capa_short_cut(mut app Appli, capa int) {
	if mut app is App {
		if !app.changing_options {
			if app.id_capa_select == capa {
				app.id_capa_select = -1
			} else if capa < app.players_units_liste[app.player_id_turn][app.troop_select.id].capas.len {
				app.id_capa_select = capa
			}
		}
	}
}

// UNITS /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
fn (app App) units_render(transparency u8) {
	// units
	for coo_x in 0 .. app.world_map.len {
		for coo_y in 0 .. app.world_map[coo_x].len {
			pos_x, pos_y := hexagons.coo_hexa_x_to_ortho(coo_x + app.dec_x, coo_y + app.dec_y)
			for mut troop in app.world_map[coo_x][coo_y][1..] {
				match mut troop {
					Troops {
						team := troop.team_nb
						unit_id := troop.id
						app.players_units_liste[team][unit_id].render(app.ctx, app.radius,
							pos_x * app.radius, pos_y * app.radius, transparency, app)
					}
					else {}
				}
			}
		}
	}

	// selected unit
	if app.in_selection {
		pos_x, pos_y := hexagons.coo_hexa_x_to_ortho(app.pos_select_x + app.dec_x,
			app.pos_select_y + app.dec_y)
		team := app.troop_select.team_nb
		unit_id := app.troop_select.id
		app.players_units_liste[team][unit_id].render(app.ctx, app.radius, pos_x * app.radius,
			pos_y * app.radius, transparency - 100, app)
		app.players_units_liste[team][unit_id].stats_render(app.ctx, unit_id, app, transparency)
	}
}

// for referencing in app.world_map
struct Troops {
mut:
	color   gg.Color = gg.Color{125, 125, 125, 255}
	team_nb int
	id      int
}

struct Units {
	mouvements_max int    @[required]
	pv_max         int    @[required]
	name           string @[required]
mut:
	mouvements     int
	pv             int @[required]
	capas          []string
	color          gg.Color = gg.Color{125, 125, 125, 255} @[skip]
	status_effects []int    = []int{len: int(Effects.end_timed_effects)}    @[skip]

	capa_used bool @[skip]
}

fn (mut unit Units) set_mouvements() {
	unit.mouvements = unit.mouvements_max
	unit.capa_used = false
}

fn (mut unit Units) status_change(app App) {
	for id, mut value in unit.status_effects {
		value = app.effects_functions[id](mut unit, value)
	}
}

fn (mut unit Units) damage(effects []int, app App) {
	for id, value in effects {
		if id < int(Effects.end_timed_effects) {
			unit.status_effects[id] += value
		} else if id < int(Effects.end_effects) && id != int(Effects.end_timed_effects) {
			app.effects_functions[id](mut unit, value)
		}
	}
}

fn (unit Units) render(ctx gg.Context, radius f32, pos_x f32, pos_y f32, transparency u8, app App) {
	ctx.draw_circle_filled(pos_x, pos_y, radius - 10, attenuation(unit.color, transparency))
	if image := app.map_image[unit.name] {
		ctx.draw_image(pos_x - radius / 2, pos_y - radius / 2, radius, radius, image)
	} else {
		ctx.draw_image(pos_x - radius / 2, pos_y - radius / 2, radius, radius, app.map_image['error'] or {
			panic('No image')
		})
	}
}

fn (unit Units) stats_render(ctx gg.Context, id int, app App, transparency u8) {
	mut txt := 'UNIT Select:
	${unit.name}: ${id}
	Pv: ${unit.pv}/${unit.pv_max}
	Mouvements: ${unit.mouvements}/${unit.mouvements_max}
	Status: ${unit.status_effects}
	Capas: ${app.id_capa_select}/${unit.capas.len}'
	if unit.capa_used {
		txt += ' \nCapa already used'
	}
	if app.id_capa_select > -1 {
		key := unit.capas[app.id_capa_select]
		name := app.map_capa_exist[key].name
		txt += ' \n${name}'
	}
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 64, app.ctx.height / 2,
		true, true, txt, transparency - 40)
}

// Attack
struct Capas {
	name string @[required]
mut:
	attacks []Attack @[required]
}

fn (capa Capas) previsualisation(app App) [][]int {
	mut concerned := [][]int{}
	for attack in capa.attacks {
		concerned << attack.forme(app)
	}
	return concerned
}

fn (mut capa Capas) use(mut app App) {
	for attack in capa.attacks {
		attack.fire(mut app)
	}
}

enum Possible_shape {
	zone
	line

	// a ray is like a line but end up whenever it cross an ennemy
	ray
}

struct Attack {
mut:
	// shape:
	max_distance int
	range        int @[required]
	shape_type   int @[required]

	effects []int = []int{len: int(Effects.end_effects)} @[required]
	// it len is the nb of Effects possibles
}

fn (attack Attack) fire(mut app App) {
	concerned := attack.forme(app)
	for pos in concerned {
		coo_x := pos[0]
		coo_y := pos[1]
		if coo_x >= 0 && coo_y >= 0 {
			for troop in app.world_map[coo_x][coo_y][1..] {
				if troop is Troops {
					app.players_units_liste[troop.team_nb][troop.id].damage(attack.effects,
						app)
				}
			}
			if coo_x == app.pos_select_x && coo_y == app.pos_select_y {
				app.players_units_liste[app.troop_select.team_nb][app.troop_select.id].damage(attack.effects,
					app)
			}
		}
	}
}

fn (attack Attack) forme(app App) [][]int {
	len_x := app.world_map.len + app.dec_x
	len_y := app.world_map[0].len + app.dec_y
	pos_x := app.ctx.mouse_pos_x / app.radius
	pos_y := app.ctx.mouse_pos_y / app.radius
	mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(pos_x, pos_y, len_x, len_y)

	dir := hexagons.direction_to_pos_x(app.pos_select_x + app.dec_x, app.pos_select_y + app.dec_y,
		pos_x, pos_y)

	coo_x -= app.dec_x
	coo_y -= app.dec_y

	mut concerned := [[coo_x, coo_y]]

	match Possible_shape.from(attack.shape_type) or { panic('') } {
		.zone {
			distance := hexagons.distance_hexa_x(app.pos_select_x, app.pos_select_y, coo_x,
				coo_y)
			if attack.max_distance >= distance {
				concerned << hexagons.neighbors_hexa_x_in_range(coo_x, coo_y, len_x, len_y,
					attack.range)
				return concerned
			}
			return [][]int{}
		}
		.line {
			return hexagons.line_hexa_x(app.pos_select_x, app.pos_select_y, len_x, len_y,
				dir, attack.range)
		}
		.ray {
			target_x, target_y, dist := hexagons.ray_cast_hexa_x(app.pos_select_x, app.pos_select_y,
				dir, app.world_map, attack.range, 1)
			if 0 < dist && dist <= attack.range {
				return [[target_x, target_y]]
			}
			return [][]int{}
		}
	}
}

// Effects
enum Effects {
	poison
	bleed
	regeneration
	stun

	end_timed_effects

	damage
	heal

	end_effects
}

// timed
fn poison_fn(mut unit Units, value int) int {
	if value <= 0 {
		return 0
	}
	unit.pv -= 1
	return value - 1
}

fn bleed_fn(mut unit Units, value int) int {
	if value <= 0 {
		return 0
	}
	unit.pv -= 1
	return value - 1
}

fn regeneration_fn(mut unit Units, value int) int {
	if value <= 0 {
		return 0
	}
	if unit.pv < unit.pv_max {
		unit.pv += 1
	}
	return value - 1
}

fn stun_fn(mut unit Units, value int) int {
	if value <= 0 {
		return 0
	}
	unit.capa_used = true
	unit.mouvements = 0
	return value - 1
}

// not timed
fn damage_fn(mut unit Units, value int) int {
	unit.pv -= value
	return 0
}

fn heal_fn(mut unit Units, value int) int {
	unit.pv += value
	if unit.pv > unit.pv_max {
		unit.pv = unit.pv_max
	}
	return 0
}

fn (mut app App) effects_initialistation() {
	app.effects_functions = []Effect_fn{len: int(Effects.end_effects)}

	// timed
	app.effects_functions[int(Effects.poison)] = poison_fn
	app.effects_functions[int(Effects.bleed)] = bleed_fn
	app.effects_functions[int(Effects.regeneration)] = regeneration_fn
	app.effects_functions[int(Effects.stun)] = stun_fn

	// not timed
	app.effects_functions[int(Effects.heal)] = heal_fn
	app.effects_functions[int(Effects.damage)] = damage_fn
}

// Buttons: ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// start
fn game_start(mut app Appli) {
	if mut app is App {
		app.playing = true
		app.in_waiting_screen = true
		app.in_placement_turns = true
		app.player_id_turn = app.player_liste.len - 1
	}
	if mut app is playint.Opt {
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
		// Change the current player
		if app.player_id_turn == 0 {
			app.player_id_turn = app.player_liste.len - 1
			if app.in_placement_turns {
				app.in_placement_turns = false
			}
		} else {
			app.player_id_turn -= 1
		}

		// reset some variables
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
		for mut unit in mut app.players_units_liste[app.player_id_turn] {
			unit.set_mouvements()
			unit.status_change(app)
		}
		app.check_death()
		app.id_capa_select = -1
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

fn next_state(mut app Appli) {
	if start_is_actionnable(mut app) {
		game_start(mut app)
	} else if start_turn_is_actionnable(mut app) {
		start_turn(mut app)
	} else if end_turn_is_actionnable(mut app) {
		end_turn(mut app)
	}
}
