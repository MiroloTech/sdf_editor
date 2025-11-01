module graph

import gg
import math
import sokol.sapp

import std { Color }
import std.geom2 { Vec2 }

pub struct CustomPinDataStyle {
	pub mut:
	rounding        f64                     = 2.0
	width           f64                     = 60.0
	padding         f64                     = 4.0
	text_size       int                     = 12
	
	text_color      Color                   = Color.hex("#dddddd")
	tag_color       Color                   = Color.hex("#888888")
	bg_color        Color                   = Color.hex("#333333cc")
	hovered_color   Color                   = Color.hex("#666666cc")
	count_color     Color                   = Color.hex("#888888")
	
	font_path       string                  = "${@VMODROOT}/graph/assets/SourceCodePro-Medium.ttf"
}

pub interface CustomPinData {
	style CustomPinDataStyle
	
	draw(mut ctx gg.Context, pos Vec2, size Vec2, name string)
	get_value_str() string
	
	mut:
	event(event &gg.Event, pos Vec2, size Vec2)
}


// ======== NUMBER ========

pub struct CustomPinDataFloat {
	pub:
	style      CustomPinDataStyle
	
	pub mut:
	value      f32
	step       f64                     = 0.1
	increment  f64                     = 0.01
	
	mut:
	relative   f64
	dragging   bool
	hovering   bool
}

pub fn (pin_data CustomPinDataFloat) draw(mut ctx gg.Context, pos Vec2, size Vec2, pin_name string) {
	// Draw BG
	ctx.draw_rounded_rect_filled(
		f32(pos.x), f32(pos.y),
		f32(size.x), f32(size.y),
		f32(pin_data.style.rounding),
		pin_data.style.bg_color.get_gx()
	)
	
	
	// Draw tag
	ctx.set_text_cfg(
		color:           pin_data.style.tag_color.get_gx()
		family:          pin_data.style.font_path
		size:            pin_data.style.text_size
		vertical_align:  .middle
		align:           .left
	)
	
	tag_text := "${pin_name} "
	ctx.draw_text_default(
		int(pos.x + pin_data.style.padding),
		int(pos.y + size.y * 0.5),
		tag_text
	)
	
	// Draw value
	ctx.set_text_cfg(
		color:           pin_data.style.text_color.get_gx()
		family:          pin_data.style.font_path
		size:            pin_data.style.text_size
		vertical_align:  .middle
		align:           .left
	)
	
	v := math.floor(pin_data.value / pin_data.step) * pin_data.step
	ctx.draw_text_default(
		int(pos.x + pin_data.style.padding) + ctx.text_width(tag_text),
		int(pos.y + size.y * 0.5),
		"${v:.3}"
	)
	
	// Control Mouse Shape
	if pin_data.hovering || pin_data.dragging {
		sapp.set_mouse_cursor(.resize_ew)
	}
}

pub fn (mut pin_data CustomPinDataFloat) event(event &gg.Event, pos Vec2, size Vec2) {
	mpos := Vec2{event.mouse_x, event.mouse_y}
	if pos.x < mpos.x && mpos.x <= pos.x + size.x  &&  pos.y < mpos.y && mpos.y <= pos.y + size.y {
		pin_data.hovering = true
		if event.typ == .mouse_down && event.mouse_button == .left {
			pin_data.dragging = true
		}
	} else {
		pin_data.hovering = false
	}
	
	if event.typ == .mouse_up && event.mouse_button == .left {
		// pin_data.relative = 0.0
		pin_data.dragging = false
	}
	
	if pin_data.dragging && event.typ == .mouse_move {
		pin_data.relative += event.mouse_dx * pin_data.increment
		pin_data.value = f32(math.round(pin_data.relative / pin_data.step) * pin_data.step)
	}
}

pub fn (pin_data CustomPinDataFloat) get_value_str() string {
	return "${pin_data.value}"
}



// ======== BOOLEAN ========

pub struct CustomPinDataBool {
	pub:
	style      CustomPinDataStyle
	
	pub mut:
	value      bool
	
	mut:
	hovering   bool
}

pub fn (pin_data CustomPinDataBool) draw(mut ctx gg.Context, pos Vec2, size Vec2, pin_name string) {
	// Draw BG
	ctx.draw_rounded_rect_filled(
		f32(pos.x), f32(pos.y),
		f32(size.y), f32(size.y),
		f32(pin_data.style.rounding),
		if pin_data.hovering { pin_data.style.bg_color.get_gx() } else { pin_data.style.hovered_color.get_gx() }
	)
	
	// Draw Check
	if pin_data.value {
		check_points := [
			Vec2{pos.x + size.y * 0.2,  pos.y + size.y * 0.5},
			Vec2{pos.x + size.y * 0.5,  pos.y + size.y * 0.8},
			Vec2{pos.x + size.y * 0.8,  pos.y + size.y * 0.2},
		]
		
		for p in check_points {
			ctx.draw_circle_filled(
				f32(p.x), f32(p.y),
				f32(pin_data.style.rounding * 0.5),
				pin_data.style.text_color.get_gx()
			)
		}
		
		for i in 0..check_points.len - 1 {
			p := check_points[i]
			next_p := check_points[i + 1]
			std.draw_thick_line(
				mut ctx,
				f32(p.x), f32(p.y),
				f32(next_p.x), f32(next_p.y),
				f32(pin_data.style.rounding),
				pin_data.style.text_color.get_gx(),
			)
		}
	}
	
	// Draw Text
	ctx.set_text_cfg(
		color:           pin_data.style.tag_color.get_gx()
		family:          pin_data.style.font_path
		size:            pin_data.style.text_size
		vertical_align:  .middle
		align:           .left
	)
	
	ctx.draw_text_default(
		int(pos.x + size.y + pin_data.style.padding),
		int(pos.y + size.y * 0.5),
		pin_name
	)
	
	if pin_data.hovering {
		sapp.set_mouse_cursor(.pointing_hand)
	}
}

pub fn (mut pin_data CustomPinDataBool) event(event &gg.Event, pos Vec2, size Vec2) {
	mpos := Vec2{event.mouse_x, event.mouse_y}
	if pos.x < mpos.x && mpos.x <= pos.x + size.y  &&  pos.y < mpos.y && mpos.y <= pos.y + size.y {
		pin_data.hovering = true
		if event.typ == .mouse_down && event.mouse_button == .left {
			pin_data.value = !pin_data.value
		}
	} else {
		pin_data.hovering = false
	}
}

pub fn (pin_data CustomPinDataBool) get_value_str() string {
	return (if pin_data.value { "true" } else { "false" })
}

