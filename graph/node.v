module graph

import gg

import std { Color }
import std.geom2 { Vec2 }
import objects { Node }


pub enum PinShape {
	circle
	square
	diamond
}

@[heap]
pub struct GraphNode {
	pub mut:
	pos               Vec2
	size              Vec2
	
	name              string
	icon              string
	pins_in           []GraphPin
	pins_out          []GraphPin
	
	cl_node           Node
}

pub fn GraphNode.new_from_cl_node(cl_node Node) GraphNode {
	mut graph_node := GraphNode{}
	graph_node.cl_node = cl_node
	graph_node.name = cl_node.name
	graph_node.icon = cl_node.icon
	
	// > Inputs
	for i, arg in cl_node.args {
		mut type_data := objects.valid_cl_shader_types[arg.typ] or { continue }
		if arg.alias != "" {
			type_data.color = objects.valid_cl_shader_types[arg.alias].color
		}
		
		mut pin := GraphPin{
			uid: global_pin_count
			idx: i
			name: arg.name
			color: type_data.color
			typ: arg.typ
			shape: if type_data.vector_size == 1 { .circle } else { .diamond }
			is_input: true
			type_data: type_data
			variable_name: arg.name
		}
		global_pin_count++
		pin.init()
		graph_node.pins_in << pin
	}
	
	// > Output
	if mut type_data := objects.valid_cl_shader_types[cl_node.return_type] {
		if cl_node.return_alias != "" {
			type_data.color = objects.valid_cl_shader_types[cl_node.return_alias].color
		}
		mut pin := GraphPin{
			uid: global_pin_count
			idx: 0
			name: if cl_node.return_alias != "" { cl_node.return_alias.title() } else { cl_node.return_type }
			color: type_data.color
			typ: cl_node.return_type
			shape: if type_data.vector_size == 1 { .circle } else { .diamond }
			is_input: false
			type_data: type_data
			// variable_name: cl_node.return_type
		}
		global_pin_count++
		pin.init()
		graph_node.pins_out << pin
	}
	
	return graph_node
}


pub fn (mut node GraphNode) draw_node(mut ctx gg.Context, style Style, world_offset Vec2, is_focused bool) {
	mut x := node.pos.x + world_offset.x
	mut y := node.pos.y + world_offset.y
	height := f64(node.pins_in.len + node.pins_out.len) * style.pin_spacing + style.title_height
	width := style.node_width
	node.size = Vec2{width, height}
	
	// > Draw selection border
	if is_focused {
		border := style.hover_border
		ctx.draw_rounded_rect_filled(
			f32(x - border), f32(y - border),
			f32(width + border * 2.0), f32(height + border * 2.0),
			f32(style.node_rounding),
			style.node_broder_color.get_gx()
		)
	}
	
	// > Draw BG
	ctx.draw_rounded_rect_filled(
		f32(x), f32(y),
		f32(width), f32(height),
		f32(style.node_rounding),
		style.node_color.get_gx()
	)
	
	// > Draw title
	ctx.draw_rounded_rect_filled(
		f32(x), f32(y),
		f32(width), f32(style.title_height),
		f32(style.node_rounding),
		Color.hex("#ffffff22").get_gx()
	)
	ctx.draw_text(
		int(x + width * 0.5), int(y + style.title_height * 0.5),
		node.name,
		color: style.text_color.get_gx()
		size: int(style.title_height)
		vertical_align: .middle
		align: .center
	)
	y += style.title_height + style.pin_spacing * 0.5
	
	
	// > Draw right pins & titles
	x += width
	for mut pin in node.pins_out {
		// >> Draw pin shape
		pin.pos = Vec2{x, y}
		pin.draw(mut ctx, x, y, style.pin_size, style)
			
		// >> Draw pin title
		title_x := x - style.pin_size * 0.5 - style.pin_text_spacing
		ctx.draw_text(
			int(title_x), int(y),
			pin.name,
			color: style.text_color.get_gx()
			size: int(style.pin_text_size)
			vertical_align: .middle
			align: .right
		)
		
		// >> Increment y for next pin
		y += style.pin_spacing
	}
	
	// > Draw left pins & titles
	x -= width
	for mut pin in node.pins_in {
		// >> Draw pin shape
		pin.pos = Vec2{x, y}
		pin.draw(mut ctx, x, y, style.pin_size, style)
			
		// >> Draw pin title
		title_x := x + style.pin_size * 0.5 + style.pin_text_spacing
		ctx.draw_text(
			int(title_x), int(y),
			pin.name,
			color: style.text_color.get_gx()
			size: int(style.pin_text_size)
			vertical_align: .middle
			align: .left
		)
		
		// >> Increment y for next pin
		y += style.pin_spacing
	}
}


