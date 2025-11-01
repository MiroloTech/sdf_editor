module graph

import gg
import sokol.sapp
import math { mod, floor }
import time as timelib
import rand

import std.geom2 { Vec2 }
import std { Color }


@[heap]
pub struct Graph[T] {
	pub mut:
	nodes            []&UINode[T]            = []
	connections      []&UIConnection[T]      = []
	preview_conn     UIConnection[T]
	preview_pin      UIPin                   = UIPin{}
	
	// Controls
	pin_range        f64                     = 8.0              // Max range for the mouse to react to a pin
	pan              Vec2
	dot_spacing      f64                     = 50.0
	pixel_spacing    f64                     = 10.0
	toast_lifetime   f64                     = 4.0
	pos              Vec2                    = Vec2{0, 0}
	size             Vec2                    = Vec2{600, 400}
	snap             bool                    = true
	snap_size        f64                     = 10.0
	
	mut:
	node_selection   map[string]UINode[T]
	toasts           []Toast
	delta_timer      timelib.StopWatch       = timelib.new_stopwatch()
	
	// UI References
	moving_node      &UINode[T]              = unsafe { nil }
	focused_node     &UINode[T]              = unsafe { nil }
	focused_pin      &UIPin                  = unsafe { nil }
	dragging         bool
	menu             Menu                    = Menu{
		delimiter: "/"
		options: [
			/*
			"drinks/coke"
			"drinks/water"
			"drinks/juice/cranberry"
			"drinks/juice/apple"
			"food/toast"
			"food/pizza/peperoni"
			"pets"
			*/
		]
		focus: "" // drinks/juice/apple
	}
}


// ======== UI ========

pub fn (mut g Graph[T]) draw(mut ctx gg.Context) {
	ctx.scissor_rect(
		int(g.pos.x), int(g.pos.y),
		int(g.size.x), int(g.size.y),
	)
	
	window_size := Vec2{f64(ctx.window_size().width), f64(ctx.window_size().height)}
	
	
	// Draw BG Dots for orientation
	for x in 0..int(window_size.x / g.dot_spacing + 2) {
		for y in 0..int(window_size.y / g.dot_spacing + 2) {
			pos := Vec2{x * g.dot_spacing, y * g.dot_spacing} + Vec2{mod(g.pan.x, g.dot_spacing), mod(g.pan.y, g.dot_spacing)}
			ctx.draw_pixel(
				f32(pos.x), f32(pos.y),
				Color.hex("#ffffff11").get_gx(),
				size: 2.0
			)
			
			// Draw chunk of smaller BG Dots
			mut pts := []f32{}
			for x2 in 0..int(g.dot_spacing / g.pixel_spacing) {
				for y2 in 0..int(g.dot_spacing / g.pixel_spacing) {
					pts << f32(pos.x + f64(x2) * g.pixel_spacing)
					pts << f32(pos.y + f64(y2) * g.pixel_spacing)
				}
			}
			
			ctx.draw_pixels(
				pts,
				Color.hex("#66666616").get_gx()
			)
		}
	}
	
	// Draw nodes
	for node in g.nodes {
		node.draw(mut ctx, Vec2.zero())
	}
	
	// Draw connections
	for conn in g.connections {
		conn.draw(mut ctx)
	}
	
	// Draw preview connection
	if g.dragging {
		g.preview_conn.draw_pin_bridge(
			mut ctx,
			g.preview_conn.node_a.pins[g.preview_conn.pin_idx_a],
			&g.preview_pin,
			g.preview_conn.node_a.get_pin_pos(g.preview_conn.pin_idx_a),
			g.preview_pin.custom_pos
		)
	}
	
	g.menu.draw(mut ctx)
	
	g.manage_toasts(mut ctx)
}

pub fn (mut g Graph[T]) event(event &gg.Event, mut ctx gg.Context) {
	sapp.set_mouse_cursor(.default)
	
	mpos := Vec2{event.mouse_x, event.mouse_y}
	if mpos.x < g.pos.x || mpos.y < g.pos.y  ||   mpos.x >= g.pos.x + g.size.x || mpos.y >= g.pos.y + g.size.y {
		return
	}
	
	g.menu.event(event, mut ctx)
	
	if g.menu.selection != "" {
		node := g.node_selection[g.menu.selection] or {
			g.toast("${g.menu.selection} - not a valid node", .warning)
			return
		}
		g.menu.hide()
		mut new_node := g.add_node(node, mpos - Vec2{8, 8})
		new_node.focused = true
		g.focused_node = new_node
	}
	
	g.ctrl_zoom(event)
	g.ctrl_nodes(event)
	g.ctrl_connections(event)
	
	if event.typ == .mouse_down && int(event.mouse_button) == 0b1 {
		g.menu.visible = true
		g.menu.focus = "/"
		g.menu.pos = mpos - Vec2{8, 8}
	}
}


// ======== CONTROLLERS ========


fn (mut g Graph[T]) ctrl_zoom(event &gg.Event) {
	if int(event.mouse_button) >> 1 == 0b1 {
		mrel := Vec2{event.mouse_dx, event.mouse_dy}
		g.pan += mrel
		
		for mut node in g.nodes {
			node.pos += mrel
		}
		sapp.set_mouse_cursor(.resize_all)
	}
}


fn (mut g Graph[T]) ctrl_nodes(event &gg.Event) {
	mpos := Vec2{event.mouse_x, event.mouse_y}
	
	// Trigger event function for evey node
	for mut node in g.nodes {
		node.event(event)
		/*
		for pin in node.pins {
			g.toast("Pin ${pin.name}: 0x" + voidptr(pin).hex_full(), .hint)
		}
		*/
	}
	
	// Highlight hovered pin
	g.focused_pin = g.get_closest_pin(mpos) or { unsafe { nil } }
	g.focused_node = unsafe { nil }
	if g.focused_pin != unsafe { nil } {
		sapp.set_mouse_cursor(.pointing_hand)
		g.focused_node = g.get_node_from_pin(g.focused_pin)
		if g.focused_node == unsafe { nil } {
			g.focused_pin = unsafe { nil }
			g.toast("Tried to highlight node-less pin", .warning)
			return
		}
		return
	}
	
	// Highlight hovered nodes
	for i, mut node in g.nodes {
		if node.is_point_inside_head(mpos) && g.focused_pin == unsafe { nil } && event.mouse_button != .left {
			node.focused = true
			sapp.set_mouse_cursor(.resize_all)
			
			// > Delete hovered node, if button for deletion is pressed
			if event.typ == .key_down && (event.key_code == .delete  || event.key_code == .x) {
				g.delete_node(i)
				g.focused_node = unsafe { nil }
				g.toast("Node deleted", .hint)
			}
			break
		} else {
			node.focused = false
		}
	}
	
	
	if event.typ == .mouse_down {
		for mut node in g.nodes {
			if node.is_point_inside_head(mpos) && g.moving_node == unsafe { nil } {
				g.moving_node = node
			}
		}
	}
	if event.typ == .mouse_up {
		g.moving_node = unsafe { nil }
		g.focused_node = unsafe { nil }
		g.focused_pin = unsafe { nil }
	}
	
	// > Move node
	if event.mouse_button == .left && g.moving_node != unsafe { nil } && !g.dragging {
		if g.snap {
			off := Vec2{mod(g.pan.x, g.snap_size), mod(g.pan.y, g.snap_size)}
			g.moving_node.pos = Vec2{floor(mpos.x / g.snap_size) * g.snap_size, floor(mpos.y / g.snap_size) * g.snap_size} + off
		} else {
			g.moving_node.pos = mpos // - g.focused_node.title_center()
		}
		sapp.set_mouse_cursor(.resize_all)
	}
}


fn (mut g Graph[T]) ctrl_connections(event &gg.Event) {
	mpos := Vec2{event.mouse_x, event.mouse_y}
	
	g.preview_pin.custom_pos = mpos
	g.preview_pin.color = Color.hex("#ffffff")
	
	// Check for target pins
	if g.dragging {
		if g.focused_pin != unsafe { nil } {
			if g.is_valid_second_pin(g.focused_pin) {
				// > Set target
				g.preview_conn.pin_idx_b = g.focused_node.get_pin_idx(g.focused_pin) or { return }
				g.preview_conn.node_b = g.focused_node
				
				// > Snap to target
				g.preview_pin.custom_pos = g.focused_node.get_pin_pos(g.preview_conn.pin_idx_b)
				g.preview_pin.color = g.focused_pin.color
			}
		}
	}
	
	// Start new preview connection
	if event.typ == .mouse_down && event.mouse_button == .left && g.focused_pin != unsafe { nil } {
		if g.get_connections_at_pin(g.focused_pin).len > 0 && g.focused_pin.is_input {
			mut conn := g.get_connections_at_pin(g.focused_pin)[0]
			idx := g.connections.index(conn)
			if idx == -1 { return }
			
			// > Copy connection
			g.preview_conn.node_a    = conn.node_a
			g.preview_conn.pin_idx_a = conn.pin_idx_a
			g.preview_conn.node_b    = conn.node_b
			g.preview_conn.pin_idx_b = conn.pin_idx_b
			
			// > Remove is_connected state
			conn.node_a.pins[conn.pin_idx_a].is_connected = false
			conn.node_b.pins[conn.pin_idx_b].is_connected = false
			
			// > Delete connection
			g.connections.delete(idx)
			g.dragging = true
		} else if !g.focused_pin.is_input {
			pin_idx := g.focused_node.get_pin_idx(g.focused_pin) or { return }
			
			g.preview_conn.node_a = g.focused_node
			g.preview_conn.pin_idx_a = pin_idx
			g.dragging = true
		}
	}
	
	// Finish or cancel preview connection
	if event.typ == .mouse_up && event.mouse_button == .left {
		g.dragging = false
		
		if g.preview_conn.node_b != unsafe { nil } && g.focused_node != unsafe { nil } && g.focused_pin != unsafe { nil } {
			g.connections << &UIConnection[T]{
				node_a:    g.preview_conn.node_a
				pin_idx_a: g.preview_conn.pin_idx_a
				
				node_b:    g.preview_conn.node_b
				pin_idx_b: g.preview_conn.pin_idx_b
			}
			
			g.preview_conn.node_a.pins[g.preview_conn.pin_idx_a].is_connected = true
			g.preview_conn.node_b.pins[g.preview_conn.pin_idx_b].is_connected = true
			
			g.preview_conn.node_b = unsafe { nil }
			g.preview_conn.pin_idx_b = 0
		}
		
		g.preview_conn.node_a = unsafe { nil }
		g.preview_conn.pin_idx_a = 0
		g.preview_conn.node_b = unsafe { nil }
		g.preview_conn.pin_idx_b = 0
	}
}

fn (mut g Graph[T]) manage_toasts(mut ctx gg.Context) {
	// Decrement time
	delta := g.delta_timer.elapsed().seconds()
	g.delta_timer.restart()
	// widnow_size := ctx.window_size()
	
	g.toasts.update(delta)
	
	g.toasts.sort_by_time()
	g.toasts.draw(mut ctx, g.pos + g.size - Vec2{20.0, 20.0}, 15.0)
}


// ======== UTIL ========

// Returns true, if the given pin is a suitable pin for the second half of the preview connection
// TODO : Make function return error to be displayed
fn (g Graph[T]) is_valid_second_pin(pin &UIPin) bool {
	// > Don't allow in and out pin to be the same
	pin_a := g.preview_conn.node_a.pins[g.preview_conn.pin_idx_a] or { return false }
	if pin_a == pin {
		return false
	}
	
	// > Make sure, that one pin is input and one is output
	if pin_a.is_input == pin.is_input {
		return false
	}
	
	// > Make sure, the connection doesn't already exist
	if g.is_connection_existent(pin, pin_a) {
		return false
	}
	
	// > Allow only one connection for input pins
	if pin.is_input {
		for conn in g.connections {
			if conn.get_pin_a() == pin || conn.get_pin_b() == pin {
				return false
			}
		}
	}
	
	return true
}


// Returns a reference to the closest of all pins to the given position in the node graph 'pin_range'
// Returns none, if no pins were checked or no pin is in range
pub fn (g Graph[T]) get_closest_pin(pos Vec2) ?&UIPin {
	mut closest_pin_node_idx := -1
	mut closest_pin_idx := -1
	mut closest_dist := g.pin_range
	for i, node in g.nodes {
		for j, _ in node.pins {
			distance := node.get_pin_pos(j).distance_to(pos)
			if distance < closest_dist && distance < g.pin_range {
				closest_dist = distance
				closest_pin_node_idx = i
				closest_pin_idx = j
			}
		}
	}
	if closest_pin_idx == -1 || closest_pin_node_idx == -1 {
		return none
	}
	return g.nodes[closest_pin_node_idx].pins[closest_pin_idx]
}

// Returns the corresponding node to the given pin
pub fn (g Graph[T]) get_node_from_pin(pin &UIPin) &UINode[T] {
	for node in g.nodes {
		if pin in node.pins {
			return node
		}
	}
	return unsafe { nil }
}

pub fn (g Graph[T]) get_connections_at_pin(pin &UIPin) []&UIConnection[T] {
	mut connections := []&UIConnection[T]{}
	for conn in g.connections {
		if conn.get_pin_a() == pin || conn.get_pin_b() == pin {
			connections << conn
		}
	}
	return connections
}

pub fn (g Graph[T]) is_connection_existent(pin_a &UIPin, pin_b &UIPin) bool {
	for connection in g.connections {
		conn_pin_a := connection.get_pin_a()
		conn_pin_b := connection.get_pin_b()
		
		if (conn_pin_a == pin_a && conn_pin_b == pin_b)  ||  (conn_pin_a == pin_b && conn_pin_b == pin_a) {
			return true
		}
	}
	return false
}


// Creates a connection between the two given nodes and pins
pub fn (mut g Graph[T]) connect(mut node_a &UINode[T], pin_idx_a int, mut node_b &UINode[T], pin_idx_b int) ! {
	if pin_idx_a < 0 || node_a.pins.len < pin_idx_a { return error("Pin idx '${pin_idx_a}' a out of range [0, ${node_a.pins.len})") }
	if pin_idx_b < 0 || node_b.pins.len < pin_idx_b { return error("Pin idx '${pin_idx_b}' b out of range [0, ${node_b.pins.len})") }
	
	node_a.pins[pin_idx_a].is_connected = true
	node_b.pins[pin_idx_b].is_connected = true
	
	connection := &UIConnection[T]{
		node_a:        node_a
		pin_idx_a:     pin_idx_a
		
		node_b:        node_b
		pin_idx_b:     pin_idx_b
	}
	g.connections << connection
}


// Adds a selected node to the graph
pub fn (mut g Graph[T]) add_node(node UINode[T], pos Vec2) &UINode[T] {
	mut pins := []&UIPin{}
	for pin in node.pins {
		mut new_pin := &UIPin{
			...(*pin)
			uid: rand.u64()
		}
		if pin.custom_value != none {
			new_pin.custom_value = match pin.custom_value {
				CustomPinDataFloat { CustomPinData(CustomPinDataFloat{}) }
				CustomPinDataBool { CustomPinData(CustomPinDataBool{}) }
				else { break }
			}
		}
		pins << new_pin
	}
	
	new_node := &UINode[T]{
		...node
		pos: pos
		pins: pins
	}
	
	g.nodes << new_node
	return new_node
}

// Deletes a selected node to the graph
pub fn (mut g Graph[T]) delete_node(idx int) {
	// Delete all connections
	node := g.nodes[idx]
	for pin in node.pins {
		for i, conn in g.connections {
			if conn.get_pin_a() == pin || conn.get_pin_b() == pin {
				g.connections.delete(i)
			}
		}
	}
	
	g.nodes.delete(idx)
}


// Adds a selectable node to the list of possible selectables
// Note : sub-paths are made with a '/'
pub fn (mut g Graph[T]) set_node_selection(path string, node UINode[T]) {
	g.node_selection[path] = node
	g.menu.options << path
}


// Creates a notice popup
pub fn (mut g Graph[T]) toast(msg string, state ToastMessageType) {
	g.toasts.add_toast(msg, state, g.toast_lifetime)
}

