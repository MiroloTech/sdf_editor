module graph

import gg
import sokol.sapp

import std.geom2 { Vec2 }
import std { Color }
import objects { TypeData }

pub type PinValue = f32 | f64 | int

pub fn (value PinValue) str() string {
	match value {
		f32 { return "${value as f32}" }
		f64 { return "${value as f64}" }
		else { return "${value as int}" }
	}
}

pub fn (mut value PinValue) add(v f64) {
	match value {
		f32   { value = value as f32 + f32(v * 0.5) }
		f64   { value = value as f64 + f64(v * 0.5) }
		int   { value = value as int + int(v) }
	}
}


@[heap]
pub struct GraphPin {
	pub mut:
	uid               u64
	idx               int
	name              string
	color             Color
	typ               string
	shape             PinShape
	is_input          bool
	variable_name     string
	pos               Vec2
	type_data         TypeData
	custom_value      ?PinValue
	// node              &GraphNode           = unsafe { nil }
	
	mut:
	editing           bool
	tenth             bool
	is_connected      bool
}


pub fn (mut pin GraphPin) init() {
	if pin.is_input {
		match pin.typ {
			"float"    { pin.custom_value = f32(0.0) }
			"double"   { pin.custom_value = f64(0.0) }
			"int"      { pin.custom_value = int(0.0) }
			else       { pin.custom_value = none }
		}
	}
}

// returns true, if the pin can hold a custom default value, if not connection is given
pub fn (pin GraphPin) can_draw_custom() bool {
	return pin.typ in ["float", "double", "int"]
}

pub fn (pin GraphPin) draw(mut ctx gg.Context, x f64, y f64, size f64, style Style) {
	// Draw pin shape
	match pin.shape {
		.diamond {
			s := size * 0.5
			ctx.draw_convex_poly(
				[
					f32(x - s), f32(y),
					f32(x),     f32(y - s),
					f32(x + s), f32(y),
					f32(x),     f32(y + s),
				],
				pin.color.get_gx()
			)
		}
		.square {
			ctx.draw_square_filled(
				f32(x), f32(y),
				f32(size),
				pin.color.get_gx()
			)
		}
		else {
			ctx.draw_circle_filled(
				f32(x), f32(y),
				f32(size * 0.4),
				pin.color.get_gx()
			)
		}
	}
	
	// Draw custom value, if neccessary
	if pin.is_input && pin.can_draw_custom() && pin.custom_value != none && !pin.is_connected {
		// > Draw BG
		s := style.pin_spacing + style.pin_size * 0.5
		ctx.draw_rounded_rect_filled(
			f32(x + s), f32(y - style.pin_input_height * 0.5),
			f32(style.node_width - s - style.pin_spacing * 0.5), f32(style.pin_input_height),
			f32(style.node_rounding),
			Color.hex("#ffffff44").get_gx()
		)
		
		// > Draw value
		ctx.draw_text(
			int(x + s + 4.0), int(y),
			pin.custom_value.str(),
			color: style.text_color.get_gx()
			size: int(style.pin_input_height - 2.0)
			vertical_align: .middle
		)
	}
}


pub fn (mut pin GraphPin) event(event &gg.Event, style Style) {
	if pin.is_input && pin.can_draw_custom() && pin.custom_value != none && !pin.is_connected {
		// > Draw BG
		s := style.pin_spacing + style.pin_size * 0.5
		from := Vec2{pin.pos.x + s, pin.pos.y - style.pin_input_height * 0.5}
		to := from + Vec2{style.node_width - s - style.pin_spacing * 0.5, style.pin_input_height}
		
		if event.typ == .mouse_move && pin.editing {
			if pin.tenth {
				pin.custom_value.add(f64(event.mouse_dx) * 0.1)
			} else {
				pin.custom_value.add(f64(event.mouse_dx))
			}
		}
		
		if event.typ == .mouse_down && event.mouse_button == .left {
			mpos := Vec2{event.mouse_x, event.mouse_y}
			if from.x <= mpos.x && mpos.x < to.x  &&  from.y <= mpos.y && mpos.y < to.y {
				pin.editing = true
				pin.tenth = false
				sapp.show_mouse(false)
			}
		}
		if event.typ == .mouse_up && event.mouse_button == .left {
			pin.editing = false
			pin.tenth = false
			sapp.show_mouse(true)
		}
		
		if event.typ == .key_down && event.key_code == .left_shift {
			pin.tenth = true
		}
		if event.typ == .key_up {
			pin.tenth = false
		}
	}
}

pub fn (pin GraphPin) get_variable() string {
	return "var${pin.uid}"
}