module graph

import gg
import math
import sokol.sapp

import std { Color }
import std.geom2 { Vec2 }
import objects { Node }

const output_node_name := "Output"

__global (
	global_pin_count = u64(1)
)

pub struct Style {
	pub mut:
	bg_color               Color         = Color.hex("#1d1d1d")
	node_color             Color         = Color.hex("#303030")
	node_broder_color      Color         = Color.hex("#ffffff")
	text_color             Color         = Color.hex("#ffffff")
	ctx_menu_color         Color         = Color.hex("#101010")
	
	title_height           f64           = 15.0
	node_width             f64           = 100.0
	node_rounding          f64           = 3.0
	pin_input_height       f64           = 18.0
	pin_spacing            f64           = 20.0
	pin_size               f64           = 10.0
	pin_text_spacing       f64           = 5.0
	pin_text_size          int           = 12
	hover_border           f64           = 4.0
	pan_speed              f64           = 1.0
	bg_dot_interval        f64           = 50.0
	bg_dot_size            f64           = 2.0
	line_width             f64           = 4.0
	
	ctx_menu_width         f64           = 90.0
	ctx_menu_rounding      f64           = 6.0
	ctx_menu_option_height f64           = 20.0
	ctx_menu_padding       f64           = 4.0
	
	// TODO : Add custom font support
}

@[heap]
pub struct Graph {
	pub mut:
	nodes             []GraphNode
	connections       []GraphConnection
	registered_nodes  map[string]Node
	style             Style             = Style{}
	ctx_menu          ContextMenu       = ContextMenu{}
	
	foucsed_node      int               = -1
	dragging_node     int               = -1
	panning           bool
	curr_connection   GraphConnection   = GraphConnection{}
	mouse_pin         GraphPin          = GraphPin{color: Color.hex("#00000000")}
	variables         int
	
	pan               Vec2
	pos               Vec2
	size              Vec2
}

pub fn (mut node_graph Graph) draw(mut ctx gg.Context) {
	// Draw BG
	ctx.draw_rect_filled(
		f32(node_graph.pos.x), f32(node_graph.pos.y),
		f32(node_graph.size.x), f32(node_graph.size.y),
		node_graph.style.bg_color.get_gx()
	)
	ctx.scissor_rect(
		int(node_graph.pos.x), int(node_graph.pos.y),
		int(node_graph.size.x), int(node_graph.size.y),
	)
	
	// Draw BG dots
	for x in 0..int(node_graph.size.x / node_graph.style.bg_dot_interval + 2) {
		for y in 0..int(node_graph.size.y / node_graph.style.bg_dot_interval + 2) {
			poff := Vec2{math.mod(node_graph.pan.x, node_graph.style.bg_dot_interval), math.mod(node_graph.pan.y, node_graph.style.bg_dot_interval)}
			p := Vec2{x * node_graph.style.bg_dot_interval, y * node_graph.style.bg_dot_interval} + poff
			ctx.draw_circle_filled(
				f32(p.x), f32(p.y),
				f32(node_graph.style.bg_dot_size),
				Color.hex("#ffffff22").get_gx()
			)
		}
	}
	
	// Draw nodes
	for i, mut node in node_graph.nodes {
		is_focused := node_graph.foucsed_node == i
		world_offset := node_graph.pos + node_graph.pan
		node.draw_node(
			mut ctx,
			node_graph.style,
			world_offset,
			is_focused
		)
	}
	
	// Draw connections
	mut active_connections := node_graph.connections.clone()
	active_connections << node_graph.curr_connection
	for connection in active_connections {
		if !(connection.from == unsafe { nil } || connection.to == unsafe { nil }) {
			ctx.draw_line_with_config(
				f32(connection.from.pos.x), f32(connection.from.pos.y - node_graph.style.line_width * 0.5),
				f32(connection.to.pos.x), f32(connection.to.pos.y - node_graph.style.line_width * 0.5),
				thickness: f32(node_graph.style.line_width)
				color: connection.from.color.get_gx()
			)
		}
	}
	
	// Draw Context Menu
	node_graph.ctx_menu.draw(mut ctx, node_graph.style)
}


pub fn (mut node_graph Graph) event(event &gg.Event) {
	mut mpos := Vec2{event.mouse_x, event.mouse_y}
	if !(node_graph.pos.x < mpos.x && mpos.x < node_graph.pos.x + node_graph.size.x  &&  node_graph.pos.y < mpos.y && mpos.y < node_graph.pos.y + node_graph.size.y) {
		sapp.set_mouse_cursor(.default)
		return
	}
	
	for mut pin in node_graph.get_all_pins() {
		is_connected := node_graph.get_connections_at_pin(*pin).len > 0
		pin.is_connected = is_connected
		pin.event(event, node_graph.style)
	}
	node_graph.ctx_menu.event(event, node_graph.style)
	
	// > Update mouse data
	if node_graph.panning {
		sapp.set_mouse_cursor(.resize_all)
	} else {
		if node_graph.foucsed_node != -1 {
			sapp.set_mouse_cursor(.pointing_hand)
		} else {
			sapp.set_mouse_cursor(.default)
		}
	}
	
	
	// > Move nodes
	if event.typ == .mouse_move {
		node_graph.mouse_pin.pos = mpos
		mpos -= node_graph.pos
		mpos -= node_graph.pan
		if node_graph.panning {
			node_graph.pan += Vec2{event.mouse_dx * node_graph.style.pan_speed, event.mouse_dy * node_graph.style.pan_speed}
		} else {
			if node_graph.dragging_node == -1 {
				mut is_hovered := false
				for i, node in node_graph.nodes {
					hovering := node.pos.x <= mpos.x && mpos.x < node.pos.x + node.size.x  &&  node.pos.y <= mpos.y && mpos.y < node.pos.y + node_graph.style.title_height
					if hovering {
						is_hovered = true
						node_graph.foucsed_node = i
						break
					}
				}
				if !is_hovered {
					node_graph.foucsed_node = -1
				}
			} else {
				node_graph.nodes[node_graph.dragging_node].pos = mpos
			}
		}
	}
	if event.typ == .mouse_down {
		if event.mouse_button == .left {
			node_graph.dragging_node = node_graph.foucsed_node
			if node_graph.foucsed_node != -1 {
				return
			}
		}
		if event.mouse_button == .middle {
			node_graph.panning = true
		}
	}
	if event.typ == .mouse_up {
		if event.mouse_button == .left {
			node_graph.dragging_node = -1
		}
		node_graph.panning = false
	}
	
	
	// > Move active connection
	if event.typ == .mouse_down {
		if event.mouse_button == .left {
			if node_graph.ctx_menu.selected_path != "" {
				if node_graph.ctx_menu.selected_path in node_graph.registered_nodes.keys() {
					node := node_graph.registered_nodes[node_graph.ctx_menu.selected_path] or { return }
					mpos -= node_graph.pos
					mpos -= node_graph.pan
					mut graph_node := GraphNode.new_from_cl_node(node)
					graph_node.pos.x = mpos.x - node_graph.style.node_width * 0.5
					graph_node.pos.y = mpos.y - node_graph.style.title_height * 0.5
					node_graph.nodes << graph_node
					node_graph.ctx_menu.visible = false
					node_graph.foucsed_node = node_graph.nodes.len - 1
					node_graph.dragging_node = node_graph.foucsed_node
				}
			} else {
				hovered_pin := node_graph.get_pin_at_pos(mpos)
				if hovered_pin != unsafe { nil } {
					// >> Place Connection
					if !hovered_pin.is_input {
						node_graph.curr_connection.from = hovered_pin
						node_graph.curr_connection.to = &node_graph.mouse_pin
					}
					// >> Erase Connection
					else {
						for i, connection in node_graph.connections {
							if *connection.to == *hovered_pin {
								// >>> Remove old connection
								node_graph.connections.delete(i)
								
								// >>> Represent connection in preview connection
								node_graph.curr_connection.from = connection.from
								node_graph.curr_connection.to = &node_graph.mouse_pin
							}
						}
					}
				}
			}
		}
	}
	if event.typ == .mouse_up {
		if event.mouse_button == .left && node_graph.curr_connection.from != unsafe { nil } {
			hovered_pin := node_graph.get_pin_at_pos(mpos)
			if hovered_pin != unsafe { nil } {
				if are_pins_compatible(*node_graph.curr_connection.from, hovered_pin) && hovered_pin.is_input {
					// >> Make sure, no other connection is in the pin
					is_free := node_graph.get_connections_at_pin(hovered_pin).len == 0
					if is_free {
						node_graph.curr_connection.to = hovered_pin
						if node_graph.curr_connection.is_valid() {
							node_graph.connections << node_graph.curr_connection
						}
					}
				}
			}
		}
		node_graph.curr_connection.from = unsafe { nil }
		node_graph.curr_connection.to = unsafe { nil }
	}
	
	if event.typ == .key_down {
		if event.key_code == .a && event.modifiers & 0b1 == 1 {
			node_graph.ctx_menu.pos = mpos - Vec2{5, 5}
			node_graph.ctx_menu.visible = true
		}
		if (event.key_code == .delete || event.key_code == .x) && node_graph.foucsed_node != -1 {
			// > Remove relevant connections
			mut pins := node_graph.nodes[node_graph.foucsed_node].pins_in.clone()
			pins << node_graph.nodes[node_graph.foucsed_node].pins_out
			for pin in pins {
				for connection in node_graph.get_connections_at_pin(pin) {
					conn_idx := node_graph.connections.index(*connection)
					if conn_idx != -1 {
						node_graph.connections.delete(conn_idx)
					}
				}
			}
			
			// > Remove node
			node_graph.nodes.delete(node_graph.foucsed_node)
			
			// > Reset focus
			node_graph.dragging_node = -1
			node_graph.foucsed_node = -1
		}
	}
}



// === PINS ===

// Checks variable compatibillity between the two pins
pub fn are_pins_compatible(a GraphPin, b GraphPin) bool {
	return a.type_data.vector_size == b.type_data.vector_size
}

// Returns a reference of all pins, that take data in. Mainly used to check, which pin is targeted
pub fn (node_graph Graph) get_all_pins_in() []&GraphPin {
	mut pins_in := []&GraphPin{}
	for i, node in node_graph.nodes {
		for j, _ in node.pins_in {
			pins_in << &node_graph.nodes[i].pins_in[j]
		}
	}
	return pins_in
}

// Returns a reference of all pins, that return data. Mainly used to check, which pin is targeted
pub fn (node_graph Graph) get_all_pins_out() []&GraphPin {
	mut pins_out := []&GraphPin{}
	for i, node in node_graph.nodes {
		for j, _ in node.pins_out {
			pins_out << &node_graph.nodes[i].pins_out[j]
		}
	}
	return pins_out
}

// Returns a reference of all pins in the graph
pub fn (node_graph Graph) get_all_pins() []&GraphPin {
	mut pins := []&GraphPin{}
	pins << node_graph.get_all_pins_in()
	pins << node_graph.get_all_pins_out()
	return pins
}

// Returns a reference to the pin at the given position ( accounting for the size of the pins )
// Returns 'unsafe { nil }', if no pin was found
pub fn (node_graph Graph) get_pin_at_pos(pos Vec2) &GraphPin {
	for pin in node_graph.get_all_pins() {
		dist := pin.pos.distance_to(pos)
		if dist <= node_graph.style.pin_size {
			return pin
		}
	}
	
	return unsafe { nil }
}


pub fn (node_graph Graph) get_node_at_pin(pin GraphPin) &GraphNode {
	for i, node in node_graph.nodes {
		for pin_in in node.pins_in {
			if pin_in == pin {
				return &node_graph.nodes[i]
			}
		}
		for pin_out in node.pins_out {
			if pin_out == pin {
				return &node_graph.nodes[i]
			}
		}
	}
	return unsafe { nil }
}




// === CONNECTIONS ===

// Returns a reference to all connections at the given pin. Mainly used, to walk through the graph and to make sure, that every in pin has a max of one connection
pub fn (node_graph Graph) get_connections_at_pin(pin GraphPin) []&GraphConnection {
	mut connections_at_pin := []&GraphConnection{}
	for i, connection in node_graph.connections {
		if connection.from == unsafe { nil } || connection.to == unsafe { nil } { continue }
		if *connection.from == pin || *connection.to == pin {
			connections_at_pin << &node_graph.connections[i]
		}
	}
	return connections_at_pin
}


// === COMPILE ===
pub fn (mut node_graph Graph) random_variable_name() string {
	defer { node_graph.variables += 1 }
	return "var${node_graph.variables}"
}

pub fn (node_graph Graph) get_output_node() !&GraphNode {
	mut output := unsafe { nil }
	for i, node in node_graph.nodes {
		if node.name == output_node_name {
			if output != unsafe { nil } {
				return error("Can't have more than one output node")
			}
			output = &node_graph.nodes[i]
		}
	}
	if output == unsafe { nil } {
		return error("No output node in graph")
	}
	return output
}

pub fn (node_graph Graph) get_left_node(pin GraphPin) ?&GraphNode {
	for connection in node_graph.connections {
		// println(connection)
		if connection.to.uid == pin.uid && connection.from != unsafe { nil } {
			node := node_graph.get_node_at_pin(*connection.from)
			if node == unsafe { nil } { continue }
			return node
		}
		else if connection.from.uid == pin.uid && connection.to != unsafe { nil } {
			node := node_graph.get_node_at_pin(*connection.to)
			if node == unsafe { nil } { continue }
			return node
		}
	}
	return none
}

// Finds the opposite pin of a connection with the given pin and gets the variable name from there
pub fn (node_graph Graph) get_variable_from_target_pin(pin GraphPin) ?string {
	for connection in node_graph.connections {
		// println(connection)
		if connection.to.uid == pin.uid && connection.from != unsafe { nil } {
			return connection.from.get_variable()
		}
		else if connection.from.uid == pin.uid && connection.to != unsafe { nil } {
			return connection.to.get_variable()
		}
	}
	return none
}

fn join_arr[T](arr []T, delimiter string) string {
	mut s := ""
	for i, element in arr {
		if i == arr.len - 1 {
			s += "${element}"
		} else {
			s += "${element}${delimiter}"
		}
	}
	return s
}


const graph_output_pin = GraphPin{
	uid:               0
	idx:               0
	name:              "output"
	color:             Color.hex("#000000")
	typ:               ""
	is_input:          false
	type_data:         unsafe { objects.valid_cl_shader_types["Sample"] }
}


pub fn (node_graph Graph) get_cl_source_code() !string {
	mut lines := []string{}
	mut visited := []GraphNode{}
	output_node := *(node_graph.get_output_node() or { return error("Error while starting compilation at output node : ${err}") })
	mut todo := [output_node]
	mut depth := 0

	for todo.len > 0 {
		current_todo := todo.clone()
		todo.clear()
		for node in current_todo {
			if visited.contains(node) { continue }
			mut variables := []string{}
			for pin in node.pins_in {
				if pin.is_connected {
					variable_name := node_graph.get_variable_from_target_pin(pin) or { continue }
					left_node := node_graph.get_left_node(pin) or { continue }
					todo << *left_node
					variables << variable_name
				} else {
					custom_value := pin.custom_value or { 0.0 }
					variables << "${custom_value}"
				}
			}
			output_pin := node.pins_out[0] or { graph_output_pin }
			output_var := output_pin.get_variable()
			str_vars := join_arr(variables, ", ")
			
			line := if node.cl_node.is_custom_var {
				"\t${node.cl_node.return_type} ${output_var} = ${node.cl_node.fn_name};"
			} else {
				"\t${node.cl_node.return_type} ${output_var} = ${node.cl_node.fn_name}(${str_vars});"
			}
			if line !in lines {
				lines << line
			}
			visited << node
		}
		depth += 1
		if depth == 500 {
			return error("Stack Overflow")
		}
	}
	return_line := "\treturn " + lines[0].all_after("(").all_before(")") + ";"
	lines.drop(1)
	lines.reverse_in_place()
	
	lines = sort_source_lines(lines) or { return error("Can't resort source code lines : ${err}") }
	lines << return_line
	
	return join_arr(lines, "\n")
}

fn sort_source_lines(lines []string) ![]string {
	// > Collect full line and all immediate dependencies for each avraible by name
	mut dependencies := map[string][]string{}
	mut code := map[string]string{}
	
	for line in lines {
		var_name := line.split(" ")[1] or { return error("Tried to parse invalid line : ${line}") }
		mut deps := []string{}
		for dep in line.all_after("(").all_before(")").split(", ") {
			if dep.starts_with("var") {
				deps << dep
			}
		}
		
		dependencies[var_name] = deps
		code[var_name] = line
	}
	
	mut ordered := []string{}
	mut visited := []string{}
	
	for v, _ in dependencies {
		dfs(v, mut visited, mut ordered, dependencies)
	}
	
	mut new_lines := []string{}
	for v in ordered {
		new_lines << code[v]
	}
	return new_lines
}

fn dfs(var string, mut visited []string, mut ordered []string, deps map[string][]string) {
	if var in visited {
		return
	}
	for dep in deps[var] {
		if dep in deps.keys() && dep !in ["p", "time"] {
			dfs(dep, mut visited, mut ordered, deps)
		}
	}
	visited << var
	ordered << var
}



pub fn (node_graph Graph) get_all_used_functions() string {
	mut fns := []string{}
	for node in node_graph.nodes {
		if node.cl_node.no_compile { continue }
		if fns.contains(node.cl_node.function) { continue }
		fns << node.cl_node.function
	}
	return join_arr(fns, "\n\n")
}
