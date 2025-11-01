module graph

import std { Color }
import std.geom2 { Vec2 }

import gg

pub enum PinShape {
	circle
	diamond
	square
	circle_dot
	diamond_dot
	square_dot
}

pub struct UIPinStyle {
	pub mut:
	dot_color    Color             = Color.hex("#232323")
	text_color   Color             = Color.hex("#c8c8c8")
	
	size         f64               = 4.0
	text_padd    f64               = 8.0
	preview_padd f64               = 8.0
	height       f64               = 15.0
	text_size    int               = 12
}

@[heap]
pub struct UIPin {
	pub mut:
	name         string            = "unnamed"
	color        Color             = Color.hex("#ff0000")
	shape        PinShape          = .circle
	is_input     bool              = true
	uid          u64
	is_connected bool
	
	style        UIPinStyle        = UIPinStyle{}
	custom_pos   Vec2              = Vec2.zero()                 // Used for the mouse pin, which is not attached to any node, but still needs a definitive position
	
	custom_value ?CustomPinData
}


// Draw pin at given position and given size into given context
pub fn (pin UIPin) draw(mut ctx gg.Context, pos Vec2, pin_width f64) {
	pin_size := pin.style.size
	
	// > Draw BG Shape
	match pin.shape {
		.circle, .circle_dot {
			ctx.draw_circle_filled(
				f32(pos.x), f32(pos.y),
				f32(pin_size),
				pin.color.get_gx()
			)
		}
		.diamond, .diamond_dot {
			s := pin_size
			pts := [
				f32( 0.0*s),   f32( 1.0*s),
				f32( 1.0*s),   f32( 0.0*s),
				f32( 0.0*s),   f32(-1.0*s),
				f32(-1.0*s),   f32( 0.0*s)
			]
			ctx.draw_convex_poly(
				pts, pin.color.get_gx()
			)
		}
		.square, .square_dot {
			ctx.draw_square_filled(
				f32(pos.x), f32(pos.y),
				f32(pin_size),
				pin.color.get_gx()
			)
		}
	}
	
	// > Draw Pin dot
	if pin.shape in [PinShape.circle_dot, PinShape.diamond_dot, PinShape.square_dot] {
		ctx.draw_circle_filled(
			f32(pos.x), f32(pos.y),
			f32(pin_size),
			pin.color.darken(0.5).get_gx()
		)
	}
	
	
	// > Draw preview
	if pin.custom_value != none && !pin.is_connected {
		cv_pos := pos + Vec2{pin.style.preview_padd, -pin.style.height * 0.5}
		cv_size := Vec2{pin_width - pin.style.preview_padd * 2.0, pin.style.height}
		pin.custom_value.draw(mut ctx, cv_pos, cv_size, pin.name)
	}
	// > Draw text
	else {
		if pin.is_input {
			ctx.draw_text(
				int(pos.x + pin.style.text_padd), int(pos.y),
				pin.name,
				
				size: pin.style.text_size
				align: .left
				vertical_align: .middle
				color: pin.style.text_color.get_gx()
			)
		} else {
			ctx.draw_text(
				int(pos.x - pin.style.text_padd), int(pos.y),
				pin.name,
				
				size: pin.style.text_size
				align: .right
				vertical_align: .middle
				color: pin.style.text_color.get_gx()
			)
		}
	}
	
	/*
	// DEBUG
	ctx.draw_text(
		int(pos.x), int(pos.y - 15.0),
		"${pin.uid}",
		
		size: 12
		color: pin.color.get_gx()
	)
	*/
}

pub fn (mut pin UIPin) event(event &gg.Event, pos Vec2, pin_width f64) {
	if pin.custom_value != none && !pin.is_connected {
		cv_pos := pos + Vec2{pin.style.preview_padd, -pin.style.height * 0.5}
		cv_size := Vec2{pin_width - pin.style.preview_padd * 2.0, pin.style.height}
		pin.custom_value.event(event, cv_pos, cv_size)
	}
}
