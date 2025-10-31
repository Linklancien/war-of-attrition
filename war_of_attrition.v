module main

import linklancien.playint { Appli, Button, attenuation }
import hexagons { Hexa_tile }
import os
import gg { KeyCode }
import math.vec { Vec2 }
import json
import linklancien.capas { Mark_config, Rules, Spell }
import linklancien.capas.base

const bg_color = gg.Color{0, 0, 0, 255}
const font_path = os.resource_abs_path('FontMono.ttf')

const id_mvt = 7
const id_action_point = 8

struct App {
	playint.Opt
mut:
	// for this project:
	player_name_list []string
	player_color     []gg.Color

	playing bool

	map_action_exist map[string]capas.Spell_fn
	map_unit_exist   map[string]capas.Spell_const
	map_image        map[string]gg.Image

	// for placement turns:
	placement_boundaries [][]int

	// format: [x, max_x, y max_y]
	in_placement_turns bool

	// for waitingscreen
	in_waiting_screen bool

	// for the game
	// interface Turn_based_rules:
	rule      Rules
	team_turn int
	team_nb   int = 2

	radius f32 = 30
	dec_x  int = 2
	dec_y  int = 2

	// important for save
	world_map [][][]Hexa_tile

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
	app.player_name_list << ['RED', 'BLUE']
	app.player_color << [gg.Color{125, 0, 0, 255}, gg.Color{0, 0, 125, 255}]

	app.actions_load()
	// app.units_load()
	app.images_load()

	// for p in 0 .. app.player_name_list.len {
	// 	list_unit := ['Healer', 'Tank', 'Grenade Soldier', 'Toxic Soldier']
	// 	for next in list_unit {
	// 		app.rule.team.hand[p] << [app.rule.team.permanent[p].len]
	// 		app.rule.team.permanent[p] << [
	// 			app.map_unit_exist[next],
	// 		]
	// 		app.rule.team.permanent[p][app.rule.team.permanent[p].len - 1].color = app.player_color[p]
	// 	}
	// }

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
	app.rule = base.init_rule_base(app.team_nb, capas.Deck_type.dead_array)

	app.rule.add_mark(Mark_config{
		name:        'TARGETX'
		description: 'Used to store a spell target'

		effect: target_effect
	}, Mark_config{
		name:        'TARGETY'
		description: 'Used to store a spell target'

		effect: target_effect
	}, Mark_config{
		name:        'MVT'
		description: 'Count by how many the unit have move this turn'
		effect:      mvt_effect
	}, Mark_config{
		name:        'ACTION POINTS'
		description: 'Count many action this unit can do this turn'
		effect:      action_points_effect
	})

	app.rule.add_spell(0, capas.Spell_const{
		name: 'Tank'
		// cast_fn:          [
		// 	capas.Spell_fn{
		// 		name:     'basic attack'
		// 		function: basic_attack
		// 	},
		// ]
		initiliazed_mark: {
			'PV': 10
		}
	}, capas.Spell_const{
		name: 'Healer'
		// cast_fn:          [
		// 	capas.Spell_fn{
		// 		name:     'basic attack'
		// 		function: basic_attack
		// 	},
		// ]
		initiliazed_mark: {
			'PV': 1
		}
	})
	app.rule.draw(0, 2)

	app.rule.add_spell(1, capas.Spell_const{
		name: 'Tank'
		// cast_fn:          [
		// 	capas.Spell_fn{
		// 		name:     'basic attack'
		// 		function: basic_attack
		// 	},
		// ]
		initiliazed_mark: {
			'PV':  10
			'MVT': 2
		}
	}, capas.Spell_const{
		name: 'Healer'
		// cast_fn:          [
		// 	capas.Spell_fn{
		// 		name:     'basic attack'
		// 		function: basic_attack
		// 	},
		// ]
		initiliazed_mark: {
			'PV':  1
			'MVT': 2
		}
	})
	app.rule.draw(1, 2)
}

fn on_frame(mut app App) {
	app.ctx.begin()
	if app.playing {
		app.game()
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
// LOAD:
fn (mut app App) actions_load() {
	entries := os.ls(os.join_path('capas')) or { [] }
	// load actions
	for entry in entries {
		path := os.join_path('capas', entry)
		if os.is_dir(path) {
			println('dir: ${entry}')
		} else {
			temp_action := (os.read_file(path) or { panic('No temp_action to load') })
			action := json.decode(Actions, temp_action) or {
				panic('Failed to decode json, path: ${path}, error: ${err}')
			}
			app.map_action_exist[action.name] = capas.Spell_fn{
				name:        action.name
				description: action.description
				function:    fn [action] (mut spell Spell, mut changed capas.Spell_interface) {
					if mut changed is App {
						action.use(mut spell, mut changed)
					}
				}
			}
		}
	}
}

fn (mut app App) units_load() {
	panic('To rework')
	// entries := os.ls(os.join_path('units')) or { [] }
	// load units
	// for entry in entries {
	// 	path := os.join_path('units', entry)
	// 	if os.is_dir(path) {
	// 		println('dir: ${entry}')
	// 	} else {
	// 		temp_units := (os.read_file(path) or { panic('No temp_units to load') })
	// 		unit := json.decode(Units, temp_units) or {
	// 			panic('Failed to decode json, error: ${err}')
	// 		}

	// 		app.map_unit_exist[unit.name] = unit
	// 	}
	// }
}

fn (mut app App) images_load() {
	entries := os.ls(os.join_path('images')) or { [] }
	// load units images
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

// INIT:
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

	mut capa_name := []string{len: 10, init: 'action ${index} shortcut'}
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
	for player_id in 0 .. app.player_name_list.len {
		playint.text_rect_render(app.ctx, app.text_cfg, 0, player_id * app.text_cfg.size * 2,
			false, false, app.player_name_list[player_id], transparency)
	}
}

// waiting screen
fn waiting_screen_render(app App) {
	mut transparency := u8(255)
	if app.changing_options {
		transparency = 150
	}
	txt := app.player_name_list[app.team_turn]
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
		true, true, txt, transparency)
}

// In game fn: ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
fn (mut app App) game() {
	if app.in_waiting_screen {
		waiting_screen_render(app)
	} else {
		game_render(app)
	}
}

fn (mut app App) turn() {
	if app.team_turn == 0 {
		app.team_turn = app.player_name_list.len - 1
		if app.in_placement_turns {
			app.in_placement_turns = false
		}
	} else {
		app.team_turn -= 1
	}
}

// RENDERING:
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
			mvt := app.rule.team.permanent[app.team_turn][app.troop_select.id].marks[id_mvt]
			if coo_x != -1 && coo_y != -1 && distance <= mvt {
				path = hexagons.path_to_hexa_x(app.pos_select_x, app.pos_select_y, coo_x,
					coo_y, app.world_map.len + app.dec_x, app.world_map[0].len + app.dec_y)
			}
		} else {
			// key := app.rule.team.permanent[app.team_turn][app.troop_select.id].capas[app.id_capa_select]
			// path = app.map_action_exist[key].previsualisation(app)
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
	txt := app.player_name_list[app.team_turn]
	playint.text_rect_render(app.ctx, app.text_cfg, 32, 32, true, true, txt, transparency)

	// units
	app.units_render(transparency)
	app.pv_render(transparency)

	// placements turns
	if app.in_placement_turns {
		txt_plac := 'PLACEMENT TURNS
		boundaries: ${app.placement_boundaries[app.team_turn]}'

		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, 32, true, true,
			txt_plac, transparency)

		if path.len == 0 {
			playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width / 2, app.ctx.height / 2,
				true, true, 'OUT OF BOUNDS', transparency)
		}

		team := app.team_turn
		len := app.rule.team.hand[team].len
		txt_nb := 'UNITS TO PLACE: ${len}'
		playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 128, 32, true,
			true, txt_nb, transparency)

		if len > 0 {
			// unit_id := app.rule.team.hand[team][len - 1]
			// app.rule.team.permanent[team][unit_id].stats_render(app.ctx, app,
			// 	transparency)
		}
	}
}

fn (app App) pv_render(transparency u8) {
	mut txt_pv := ''
	for id, unit in app.rule.team.permanent[app.team_turn] {
		if id == 0 {
			txt_pv += '${id}: ${unit.marks[base.id_pv]}/${unit.initiliazed_mark['PV']}'
		} else {
			txt_pv += '\n${id}: ${unit.marks[base.id_pv]}/${unit.initiliazed_mark['PV']}'
		}
	}
	playint.text_rect_render(app.ctx, app.text_cfg, 48, app.ctx.height / 2, true, true,
		txt_pv, transparency - 40)
}

// Logic:
fn (mut app App) check_placement() {
	if app.playing && !app.in_waiting_screen && !app.buttons_list[2].check(mut app) {
		mut coo_x, mut coo_y := hexagons.coo_ortho_to_hexa_x(app.ctx.mouse_pos_x / app.radius,
			app.ctx.mouse_pos_y / app.radius, app.world_map.len + app.dec_x, app.world_map[0].len +
			app.dec_y)

		coo_x -= app.dec_x
		coo_y -= app.dec_y

		if coo_x >= 0 && coo_y >= 0 && app.check_placement_possible(coo_x, coo_y) {
			if app.rule.team.hand[app.team_turn].len > 0 && app.world_map[coo_x][coo_y].len < 2 {
				app.world_map[coo_x][coo_y] << [
					Troops{
						name:    app.rule.team.hand[app.team_turn][app.rule.team.hand[app.team_turn].len - 1].name
						color:   gg.Color{125, 125, 125, 255}
						team_nb: app.team_turn
						id:      app.rule.team.next_id(app.team_turn)
					},
				]
				app.rule.play_ordered(app.team_turn, 1)
			}
		}
	}
}

fn (app App) check_placement_possible(coo_x int, coo_y int) bool {
	boundaries := app.placement_boundaries[app.team_turn]
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
			app.troop_select = tempo

			app.pos_select_x = coo_x
			app.pos_select_y = coo_y

			app.in_selection = true
		} else {
			app.world_map[coo_x][coo_y] << [tempo]
		}
	} else if app.in_selection {
		if app.id_capa_select == -1 {
			unit_move(mut app, coo_x, coo_y)
		} else {
			app.rule.team.permanent[app.team_turn][app.troop_select.id].cast_fn[app.id_capa_select].function(mut app.rule.team.permanent[app.team_turn][app.troop_select.id], mut
				app)

			app.world_map[app.pos_select_x][app.pos_select_y] << [
				Troops{
					name:    app.troop_select.name
					color:   app.troop_select.color
					team_nb: app.troop_select.team_nb
					id:      app.troop_select.id
				},
			]
			app.rule.team.update_permanent()
		}

		app.id_capa_select = -1
		app.in_selection = false
	}
}

fn unit_move(mut app App, coo_x int, coo_y int) {
	mvt := app.rule.team.permanent[app.team_turn][app.troop_select.id].marks[id_mvt]
	distance := hexagons.distance_hexa_x(app.pos_select_x, app.pos_select_y, coo_x, coo_y)
	tempo := app.troop_select
	if tempo.team_nb == app.team_turn && app.world_map[coo_x][coo_y].len < 2 && distance <= mvt {
		app.world_map[coo_x][coo_y] << tempo
		app.rule.team.permanent[app.team_turn][tempo.id].marks[id_mvt] -= distance
	} else {
		app.world_map[app.pos_select_x][app.pos_select_y] << tempo
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

fn capa_short_cut(mut app Appli, action int) {
	if mut app is App {
		if !app.changing_options {
			if app.id_capa_select == action {
				app.id_capa_select = -1
			} else if action < app.rule.team.permanent[app.team_turn][app.troop_select.id].cast_fn.len {
				app.id_capa_select = action
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
						troop.render(app.ctx, app.radius, pos_x * app.radius, pos_y * app.radius,
							transparency, app)
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
		app.troop_select.render(app.ctx, app.radius, pos_x * app.radius, pos_y * app.radius,
			transparency - 100, app)
		app.troop_select.stats_render(app.ctx, app, transparency)
	}
}

// for referencing in app.world_map
struct Troops {
mut:
	name    string
	color   gg.Color = gg.Color{125, 125, 125, 255}
	team_nb int
	id      int
}

// Units -> capas.Spell

fn (troop Troops) render(ctx gg.Context, radius f32, pos_x f32, pos_y f32, transparency u8, app App) {
	ctx.draw_circle_filled(pos_x, pos_y, radius - 10, attenuation(troop.color, transparency))
	if image := app.map_image[troop.name] {
		ctx.draw_image(pos_x - radius / 2, pos_y - radius / 2, radius, radius, image)
	} else {
		ctx.draw_image(pos_x - radius / 2, pos_y - radius / 2, radius, radius, app.map_image['error'] or {
			panic('No image')
		})
	}
}

fn (troop Troops) stats_render(ctx gg.Context, app App, transparency u8) {
	unit := app.rule.team.permanent[troop.team_nb][troop.id]
	mut txt := 'UNIT Select:
	${troop.name}: ${troop.id}
	Pv: ${unit.marks[base.id_pv]}/${unit.initiliazed_mark['PV']}
	Mouvements: ${unit.marks[id_mvt]}/${unit.initiliazed_mark['MVT']}
	Status: ${unit.marks}
	Actions: ${app.id_capa_select}/${unit.cast_fn.len}'
	if unit.marks[id_action_point] <= 0 {
		txt += ' \nCapa already used'
	}
	if app.id_capa_select > -1 {
		name := unit.cast_fn[app.id_capa_select].name
		txt += ' \n${name}'
	}
	playint.text_rect_render(app.ctx, app.text_cfg, app.ctx.width - 64, app.ctx.height / 2,
		true, true, txt, transparency - 40)
}

// EFFECTS fn

fn target_effect(id int, mut spells_list []Spell) {
	for mut spell in spells_list {
		spell.marks[id] == -1
	}
}

fn mvt_effect(id int, mut spells_list []Spell) {
	for mut spell in spells_list {
		spell.marks[id] = spell.initiliazed_mark['MVT']
	}
}

fn action_points_effect(id int, mut spells_list []Spell) {
	for mut spell in spells_list {
		spell.marks[id] = spell.initiliazed_mark['ACTION POINTS']
	}
}

// Attack
struct Actions {
	name        string   @[required]
	description string   @[required]
	cost        int      @[required]
	summons     []Summon @[required]
	attacks     []Attack @[required]
}

fn (action Actions) previsualisation(app App) [][]int {
	mut concerned := [][]int{}
	for attack in action.attacks {
		concerned << attack.forme(app)
	}
	return concerned
}

fn (action Actions) use(mut unit Spell, mut app App) {
	if unit.marks[id_action_point] >= action.cost {
		unit.marks[id_action_point] -= action.cost
		for attack in action.attacks {
			attack.fire(mut app)
		}
		for summon in action.summons {
			summon.invocation(mut app)
		}
	}
}

struct Attack {
	area         int @[required]
	range        int @[required]
	max_distance int @[required]

	damage       int            @[required]
	effects_mark map[string]int @[required]
}

enum Possible_shape {
	zone
	line

	// a ray is like a line but end up whenever it cross an ennemy
	ray
}

fn (attack Attack) fire(mut app App) {
	concerned := attack.forme(app)
	for pos in concerned {
		coo_x := pos[0]
		coo_y := pos[1]
		if coo_x >= 0 && coo_y >= 0 {
			for troop in app.world_map[coo_x][coo_y][1..] {
				if troop is Troops {
					base.inflict_damage(mut app.rule.team.permanent[troop.team_nb][troop.id],
						attack.damage)
					base.inflict_effect(mut app.rule.team.permanent[troop.team_nb][troop.id],
						app.rule, attack.effects_mark)
				}
			}
			if coo_x == app.pos_select_x && coo_y == app.pos_select_y {
				base.inflict_damage(mut app.rule.team.permanent[app.troop_select.team_nb][app.troop_select.id],
					attack.damage)
				base.inflict_effect(mut app.rule.team.permanent[app.troop_select.team_nb][app.troop_select.id],
					app.rule, attack.effects_mark)
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

	match Possible_shape.from(attack.area) or { panic('') } {
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

struct Summon {
	name string @[required]
}

fn (summon Summon) invocation(mut app App) {
	new_spell := app.map_unit_exist[summon.name]
	app.rule.add_spell(app.troop_select.team_nb, new_spell)
}

// Buttons: ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// start
fn game_start(mut app Appli) {
	if mut app is App {
		app.playing = true
		app.in_waiting_screen = true
		app.in_placement_turns = true
		app.team_turn = app.player_name_list.len - 1
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
		app.turn()

		// reset some variables
		if app.in_selection {
			app.world_map[app.pos_select_x][app.pos_select_y] << [
				Troops{
					name:    app.troop_select.name
					color:   app.troop_select.color
					team_nb: app.troop_select.team_nb
					id:      app.troop_select.id
				},
			]
			app.in_selection = false
		}

		app.rule.all_marks_do_effect(app.team_turn)
		app.rule.team.update_permanent()

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
