module graph

import std { Color }
import std.geom2 { Vec2 }

import math
import gg

pub struct UINodeStyle {
	pub mut:
	bg_color                 Color        = Color.hex("#444444")
	text_color               Color        = Color.hex("#c8c8c8")
	focus_border_color       Color        = Color.hex("#c8c8c8")
	
	title_height             f64          = 15.0
	rounding                 f64          = 4.0
	pin_spacing              f64          = 15.0
	focus_border_size        f64          = 2.0
}

@[heap]
pub struct UINode[T] {
	pub mut:
	title         string
	size          Vec2
	pos           Vec2
	style         UINodeStyle       = UINodeStyle{}
	data          T
	
	pins          []&UIPin
	focused       bool
}

pub fn (node UINode[T]) str() string {
	return "UINode[${typeof(T{}).name}]
	\ttitle: ${node.title}
	\tsize: ${node.size}
	\tpos: ${node.pos}
	\tdata: ${node.data}
	\tfocused: ${node.focused}
	\tpins: " + node.pins.map("0x" + voidptr(it).hex_full()).str()
	
}

// Renders the node at the position into the given context
pub fn (node UINode[T]) draw(mut ctx gg.Context, offset Vec2) {
	node_pos := node.pos + offset
	node_size := Vec2{node.size.x, math.max(node.size.y, node.style.title_height + f64(node.pins.len + 1) * node.style.pin_spacing)}
	
	// > Draw focus border
	if node.focused {
		ctx.draw_rounded_rect_filled(
			f32(node_pos.x  - node.style.focus_border_size),       f32(node_pos.y  - node.style.focus_border_size),
			f32(node_size.x + node.style.focus_border_size * 2.0), f32(node_size.y + node.style.focus_border_size * 2.0),
			f32(node.style.rounding), //  + node.style.focus_border_size
			node.style.focus_border_color.get_gx()
		)
	}
	
	// > Draw BG
	ctx.draw_rounded_rect_filled(
		f32(node_pos.x), f32(node_pos.y),
		f32(node_size.x), f32(node_size.y),
		f32(node.style.rounding),
		node.style.bg_color.get_gx()
	)
	
	// > Draw Title
	std.draw_special_rounded_rect_filled(
		mut ctx,
		f32(node_pos.x), f32(node_pos.y),
		f32(node_size.x), f32(node.style.title_height),
		Color.hex("#ffffff33").get_gx(),
		r1: f32(node.style.rounding),
		r2: f32(node.style.rounding),
		segments: 8
	)
	
	title_center := Vec2{node_pos.x + node_size.x * 0.5, node_pos.y + node.style.title_height * 0.5}
	
	ctx.draw_text(
		int(title_center.x), int(title_center.y),
		node.title,
		
		size: int(node.style.title_height - 0)
		align: .center
		vertical_align: .middle
		color: node.style.text_color.get_gx()
	)
	
	// > Draw Pins
	for i, pin in node.pins {
		pos := node.get_pin_pos(i)
		pin.draw(mut ctx, pos, node.size.x)
	}
}

pub fn (mut node UINode[T]) event(event &gg.Event) {
	for i, mut pin in node.pins {
		pos := node.get_pin_pos(i)
		pin.event(event, pos, node.size.x)
	}
}


// Returns the local position of the pin with the given ID
// Returns Vec2.zero(), when idx is out of range
pub fn (node UINode[T]) get_pin_pos(idx int) Vec2 {
	start := node.style.title_height + node.style.pin_spacing
	y := start + idx * node.style.pin_spacing
	pin := node.pins[idx] or { return Vec2.zero() }
	if pin.is_input {
		return Vec2{0.0, y} + node.pos
	} else {
		return Vec2{node.size.x, y} + node.pos
	}
}


pub fn (node UINode[T]) get_pin_idx(pin &UIPin) !int {
	for i, p in node.pins {
		if p == pin {
			return i
		}
	}
	return error("Pin not found")
}

// Returns the center of the title
pub fn (node UINode[T]) title_center() Vec2 {
	return Vec2{node.size.x * 0.5, node.style.title_height * 0.5}
}


// Returns true, if the point is in the rect defining the node
// Note : variable p is for *local* graph position
pub fn (node UINode[T]) is_point_inside_head(p Vec2) bool {
	return node.pos.x < p.x && p.x < node.pos.x + node.size.x  &&  node.pos.y < p.y && p.y < node.pos.y + node.style.title_height
}


// Adds a new proper pin to the array of pins
pub fn (node UINode[T]) add_pin(name string, is_input bool, color Color, shape PinShape) {
	// TODO
}

pub fn (node &UINode[T]) get_input_pins() []&UIPin {
	mut pins := []&UIPin{}
	for pin in node.pins {
		if pin.is_input {
			pins << pin
		}
	}
	return pins
}

pub fn (node &UINode[T]) get_output_pins() []&UIPin {
	mut pins := []&UIPin{}
	for pin in node.pins {
		if !pin.is_input {
			pins << pin
		}
	}
	return pins
}

