module main

import gg
import math
import sokol.sapp

import std.geom3 { Vec3, deg2rad }


pub struct Camera {
	mut:
	locked   bool      = true
	key_map  u16                     // wasdqe
	
	pub mut:
	pos      Vec3
	// dir      Vec3      = Vec3{0, 0, 1}
	pitch    f64
	yaw      f64
	roll     f64                     // TODO
	fov      f64       = 90.0
}


// Make the camera object react to the gg Event, Godot style. Make sure to call .update to make the camera move
pub fn (mut cam Camera) react_to_event(event &gg.Event, turn_speed f64) {
	// Lock / Unlock camera
	if event.typ == .mouse_down && event.mouse_button == .right {
		cam.locked = false
		sapp.show_mouse(false)
	}
	if event.typ == .mouse_up && event.mouse_button == .right {
		cam.locked = true
		cam.key_map = 0
		sapp.show_mouse(true)
	}
	
	if cam.locked { return }
	
	// Turn camera
	if event.typ == .mouse_move {
		rad := -turn_speed * (math.pi / 180.0)
		cam.pitch = math.clamp(cam.pitch + event.mouse_dy * rad, deg2rad(-89.99), deg2rad(89.99))
		cam.yaw += event.mouse_dx * rad
	}
	
	// Check for pressed keys
	if event.typ == .key_down {
		bit_map := match event.key_code {
			.w { u16(0b100000) }
			.a { u16(0b010000) }
			.s { u16(0b001000) }
			.d { u16(0b000100) }
			.q { u16(0b000010) }
			.e { u16(0b000001) }
			else { u16(0b0) }
		}
		cam.key_map |= bit_map
	}
	
	// Check for released keys
	if event.typ == .key_up {
		bit_map := match event.key_code {
			.w { u16(0b100000) }
			.a { u16(0b010000) }
			.s { u16(0b001000) }
			.d { u16(0b000100) }
			.q { u16(0b000010) }
			.e { u16(0b000001) }
			else { u16(0b0) }
		}
		cam.key_map &= ~bit_map
	}
}


// Make camera move based on active keys in camera. Make sure to call .react_to_event to determine, where to move the camera
pub fn (mut cam Camera) update(move_speed f64) {
	mut v := Vec3{0, 0, 0}
	cam_dir := cam.get_dir()
	if (cam.key_map >> 5) & 0b000001 == 1 { v += cam_dir }              // w
	if (cam.key_map >> 4) & 0b000001 == 1 { v += cam_dir.left() }       // a
	if (cam.key_map >> 3) & 0b000001 == 1 { v += cam_dir.backward() }   // s
	if (cam.key_map >> 2) & 0b000001 == 1 { v += cam_dir.right() }      // d
	if (cam.key_map >> 1) & 0b000001 == 1 { v += Vec3{0, -1, 0} }       // q
	if (cam.key_map     ) & 0b000001 == 1 { v += Vec3{0, 1, 0} }        // e
	
	v *= Vec3{move_speed, move_speed, move_speed}
	cam.pos += v
}


pub fn (cam Camera) get_dir() Vec3 {
	return Vec3{
		x: math.cos(cam.pitch) * math.cos(cam.yaw)
		y: math.sin(cam.pitch)
		z: math.cos(cam.pitch) * math.sin(cam.yaw)
	}
}
