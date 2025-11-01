module graph

import gg
import math

import std.geom2 { Vec2 }
import std
// import std { Color }

pub struct ConnectionStyle {
	pub mut:
	segments           int                = 64
	gradient_bias      f64                = 1.0
	bezier_arm_power   f64                = 0.4
	thickness          f64                = 3.0
}


pub struct UIConnection[T] {
	pub mut:
	node_a             &UINode[T]         = unsafe { nil }
	pin_idx_a          int
	
	node_b             &UINode[T]         = unsafe { nil }
	pin_idx_b          int
	
	style              ConnectionStyle    = ConnectionStyle{}
}

pub fn (conn UIConnection[T]) draw(mut ctx gg.Context) {
	pin_a := conn.node_a.pins[conn.pin_idx_a] or { return }
	pin_b := conn.node_b.pins[conn.pin_idx_b] or { return }
	
	pos_a := conn.node_a.get_pin_pos(conn.pin_idx_a)
	pos_b := conn.node_b.get_pin_pos(conn.pin_idx_b)
	
	conn.draw_pin_bridge(mut ctx, pin_a, pin_b, pos_a, pos_b)
}

pub fn (conn UIConnection[T]) draw_pin_bridge(mut ctx gg.Context, pin_a &UIPin, pin_b &UIPin, pos_a Vec2, pos_b Vec2) {
	// pin_a := conn.node_a.pins[conn.pin_idx_a] or { return }
	// pin_b := conn.node_b.pins[conn.pin_idx_b] or { return }
	
	// Make bezier Curve Control Points
	a := pos_a // conn.node_a.get_pin_pos(conn.pin_idx_a)
	d := pos_b // conn.node_b.get_pin_pos(conn.pin_idx_b)
	
	dir_a := if pin_a.is_input { -1.0 } else { 1.0 }
	dir_b := if pin_b.is_input { 1.0 } else { -1.0 }
	diff := math.abs(d.x - a.x)
	dist := a.distance_to(d)
	
	b := a + Vec2{dir_a * conn.style.bezier_arm_power * math.max(diff, math.min(100.0, dist * 2.0)), 0.0}
	c := d - Vec2{dir_b * conn.style.bezier_arm_power * math.max(diff, math.min(100.0, dist * 2.0)), 0.0}
	
	// Draw Bezier Curve
	std.draw_thick_bezier(
		mut ctx,
		a.x, a.y,
		b.x, b.y,
		c.x, c.y,
		d.x, d.y,
		conn.style.thickness,
		pin_a.color,
		pin_b.color,
		conn.style.segments
	)
}

pub fn (conn &UIConnection[T]) get_pin_a() &UIPin {
	return conn.node_a.pins[conn.pin_idx_a] or { unsafe { nil } }
}

pub fn (conn &UIConnection[T]) get_pin_b() &UIPin {
	return conn.node_b.pins[conn.pin_idx_b] or { unsafe { nil } }
}

pub fn (conn &UIConnection[T]) get_input_pin() &UIPin {
	pin_a := conn.get_pin_a()
	pin_b := conn.get_pin_b()
	if !pin_a.is_input {
		return pin_a
	}
	return pin_b
}

pub fn (conn &UIConnection[T]) get_output_pin() &UIPin {
	pin_a := conn.get_pin_a()
	pin_b := conn.get_pin_b()
	if pin_a.is_input {
		return pin_a
	}
	return pin_b
}

pub fn (conn &UIConnection[T]) get_input_node() &UINode[T] {
	if !conn.get_pin_a().is_input {
		return conn.node_a
	}
	return conn.node_b
}



