module playint

import os
import gx
import gg { KeyCode }
import math.vec { Vec2 }

const boutons_radius = 10
pub const font_path = os.resource_abs_path('playint/FontMono.ttf')

const key_code_name = {
	0:   ''
	32:  'space'
	39:  'apostrophe'
	44:  'comma'
	45:  'minus'
	46:  'period'
	47:  'slash'
	48:  '0'
	49:  '1'
	50:  '2'
	51:  '3'
	52:  '4'
	53:  '5'
	54:  '6'
	55:  '7'
	56:  '8'
	57:  '9'
	59:  'semicolon'
	61:  'equal'
	65:  'a'
	66:  'b'
	67:  'c'
	68:  'd'
	69:  'e'
	70:  'f'
	71:  'g'
	72:  'h'
	73:  'i'
	74:  'j'
	75:  'k'
	76:  'l'
	77:  'm'
	78:  'n'
	79:  'o'
	80:  'p'
	81:  'q'
	82:  'r'
	83:  's'
	84:  't'
	85:  'u'
	86:  'v'
	87:  'w'
	88:  'x'
	89:  'y'
	90:  'z'
	91:  'left_bracket'
	//[
	92:  'backslash'
	//\
	93:  'right_bracket'
	//]
	96:  'grave_accent'
	//`
	161: 'world_1'
	// non-us #1
	162: 'world_2'
	// non-us #2
	256: 'escape'
	257: 'enter'
	258: 'tab'
	259: 'backspace'
	260: 'insert'
	261: 'delete'
	262: 'right'
	263: 'left'
	264: 'down'
	265: 'up'
	266: 'page_up'
	267: 'page_down'
	268: 'home'
	269: 'end'
	280: 'caps_lock'
	281: 'scroll_lock'
	282: 'num_lock'
	283: 'print_screen'
	284: 'pause'
	290: 'f1'
	291: 'f2'
	292: 'f3'
	293: 'f4'
	294: 'f5'
	295: 'f6'
	296: 'f7'
	297: 'f8'
	298: 'f9'
	299: 'f10'
	300: 'f11'
	301: 'f12'
	302: 'f13'
	303: 'f14'
	304: 'f15'
	305: 'f16'
	306: 'f17'
	307: 'f18'
	308: 'f19'
	309: 'f20'
	310: 'f21'
	311: 'f22'
	312: 'f23'
	313: 'f24'
	314: 'f24'
	320: 'kp_0'
	321: 'kp_1'
	322: 'kp_2'
	323: 'kp_3'
	324: 'kp_4'
	325: 'kp_5'
	326: 'kp_6'
	327: 'kp_7'
	328: 'kp_8'
	329: 'kp_9'
	330: 'kp_decimal'
	331: 'kp_divide'
	332: 'kp_multiply'
	333: 'kp_subtract'
	334: 'kp_add'
	335: 'kp_enter'
	336: 'kp_equal'
	340: 'left_shift'
	341: 'left_control'
	342: 'left_alt'
	343: 'left_super'
	344: 'right_shift'
	345: 'right_control'
	346: 'right_alt'
	347: 'right_super'
	348: 'menu'
}

pub interface Appli {
mut:
	ctx &gg.Context
	opt Opt

	// Police
	text_cfg   gx.TextCfg
	bouton_cfg gx.TextCfg

	changing_options bool
	mouse_pos        Vec2[f32]
}

pub struct Opt {
mut:
	// The fonction of the action
	actions_liste []fn (mut Appli)

	// The name of the action
	actions_names []string

	// The key to get an action from an event
	event_to_action map[int]int

	// The name of the event that lead to an action
	event_name_from_action [][]string

	// Changes,  -1 -> no change
	id_change int = -1

	pause_scroll int

	// most likely between 0 & 1
	description_placement_proportion f32 = 0.5

	// most likely between 1 & 2
	bouton_placement_proportion f32 = 1.5
}

pub fn (mut opt Opt) init() {
	opt.new_action(none_fn, 'none_fn', -1)
	opt.new_action(force_close, 'force close', int(KeyCode.f4))
	opt.new_action(option_pause, 'option pause', int(KeyCode.escape))
}

fn force_close(mut app Appli) {
	app.ctx.quit()
}

fn option_pause(mut app Appli) {
	app.changing_options = !app.changing_options
}

pub fn on_event(e &gg.Event, mut app Appli) {
	if app.opt.id_change == -1 {
		match e.typ {
			.key_down {
				app.opt.input(int(e.key_code), mut app)
			}
			.mouse_down {
				match e.mouse_button {
					.left {
						// check_boutons(e.mouse_x, e.mouse_y)
					}
					else {}
				}
			}
			else {}
		}
	} else {
		app.opt.key_change(e)
	}
}

fn (mut opt Opt) input(key_code int, mut app Appli) {
	ind := opt.event_to_action[key_code]
	opt.actions_liste[ind](mut app)
}

fn (mut opt Opt) key_change(e &gg.Event) {
	match e.typ {
		.key_down {
			opt.change(int(e.key_code))
		}
		else {}
	}
}

fn (mut opt Opt) change(key_code int) {
	name := key_code_name[key_code]

	// clean the old action
	old_ind := opt.event_to_action[key_code]

	mut new := []string{}
	for elem in opt.event_name_from_action[old_ind] {
		if elem != name {
			new << [elem]
		}
	}

	opt.event_name_from_action[old_ind] = new

	new_ind := opt.id_change
	if new_ind == old_ind {
		// suppress the key
		opt.event_to_action[key_code] = 0
	} else {
		// new action
		opt.event_to_action[key_code] = new_ind
		opt.event_name_from_action[new_ind] << [name]
	}

	// reset
	opt.id_change = -1
}

pub fn (mut opt Opt) new_action(action fn (mut Appli), name string, base_key_code int) {
	opt.actions_liste << [action]
	opt.actions_names << [name]
	opt.event_name_from_action << []string{}

	new_ind := opt.event_name_from_action.len - 1

	// new action
	if base_key_code != -1 {
		opt.event_to_action[base_key_code] = new_ind
		opt.event_name_from_action[new_ind] << [key_code_name[base_key_code]]
	}
}

pub fn (mut opt Opt) settings_render(app Appli, corner bool) {
	if app.changing_options {
		for ind in 1 .. 10 {
			true_ind := ind + opt.pause_scroll
			if true_ind < opt.actions_names.len {
				x := int(app.ctx.width / 2)
				y := int(100 + ind * 40)

				mut keys_codes_names := ''
				if opt.event_name_from_action[true_ind].len > 0 {
					keys_codes_names = opt.event_name_from_action[true_ind][0]
					for name in opt.event_name_from_action[true_ind][1..] {
						keys_codes_names += ', '
						keys_codes_names += name
					}
				}

				text_rect_render(app.ctx, app.text_cfg, x * app.opt.description_placement_proportion,
					y, corner, (opt.actions_names[true_ind] + ': ' + keys_codes_names),
					u8(255))
				mut color := gx.gray
				if app.opt.id_change == true_ind {
					color = gx.red
				}
				app.ctx.draw_circle_filled(x * app.opt.bouton_placement_proportion, y + 15,
					boutons_radius, color)
			}
		}
	}
}

// Base fonctions
fn none_fn(mut app Appli) {}

// UI
pub fn text_rect_render(ctx gg.Context, cfg gx.TextCfg, x f32, y f32, corner bool, text_brut string, transparence u8) {
	text_split := text_brut.split('\n')

	mut text_len := []int{cap: text_split.len}
	mut max_len := 0

	// Precalcul
	for text in text_split {
		lenght := text.len * 8 + 10
		text_len << lenght

		if lenght > max_len {
			max_len = lenght
		}
	}

	// affichage
	mut new_x := x
	if corner == false {
		new_x -= max_len / 2
	}

	ctx.draw_rounded_rect_filled(new_x, y, max_len, cfg.size * text_split.len + 10, 5,
		attenuation(gx.gray, transparence))
	for id, text in text_split {
		new_y := y + cfg.size * id
		ctx.draw_text(int(new_x + 5), int(new_y + 5), text, cfg)
	}
}

fn attenuation(color gx.Color, new_a u8) gx.Color {
	return gx.Color{color.r, color.g, color.b, new_a}
}

// Check
pub fn check_boutons_options(mut app Appli) {
	if app.changing_options {
		for ind in 1 .. 10 {
			if ind + app.opt.pause_scroll < app.opt.actions_names.len {
				y := 115 + ind * 40
				circle_pos := Vec2[f32]{f32(app.ctx.width * app.opt.bouton_placement_proportion / 2), y}
				if point_is_in_cirle(circle_pos, boutons_radius, app.mouse_pos) {
					app.opt.id_change = ind + app.opt.pause_scroll
					break
				}
			}
		}
	}
}

pub fn point_is_in_cirle(circle_pos Vec2[f32], radius f32, mouse_pos Vec2[f32]) bool {
	if (mouse_pos - circle_pos).magnitude() < radius {
		return true
	}
	return false
}
