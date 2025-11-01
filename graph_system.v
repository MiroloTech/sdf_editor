module main

import std { Color }
import std.geom2 { Vec2 }
import objects { Node, NodeArgument }
import graph { Graph, UINode, UIPin, UIConnection, CustomPinData, CustomPinDataFloat, CustomPinDataBool }

pub fn node2uinode(node Node) UINode[Node] {
	mut pins := []&UIPin{}
	
	// Add output
	if node.return_type != "return" && node.return_type != "" {
		pins << &UIPin{
			name: ""
			color: get_type_color(if node.return_alias == "" { node.return_type } else { node.return_alias })
			is_input: false
		}
	}
	
	// Add Input
	for arg in node.args {
		mut pin := &UIPin{
			name: arg.name
			color: get_type_color(if arg.alias == "" { arg.typ } else { arg.alias })
			is_input: true
		}
		
		if !node.is_custom_var {
			match arg.typ {
				"float", "double" {
					pin.custom_value = graph.CustomPinDataFloat{}
				}
				"int" {
					pin.custom_value = graph.CustomPinDataFloat{step: 1.0, increment: 0.1}
				}
				"bool" {
					pin.custom_value = graph.CustomPinDataBool{}
				}
				else {}
			}
		}
		
		pins << pin
	}
	
	// Construct Dummy Node
	return UINode[Node]{
		title: node.name
		size: Vec2{90, 0}
		pins: pins
		data: node
	}
}

fn get_type_color(typ string) Color {
	if typ in objects.valid_cl_shader_types {
		return objects.valid_cl_shader_types[typ].color
	}
	return Color.hex("#ffffff")
}



// ===== COMPILATION =====

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


pub fn get_output_node(node_graph &Graph[Node]) !&UINode[Node] {
	mut output := unsafe { nil }
	for node in node_graph.nodes {
		if node.title == "Output" {
			if output != unsafe { nil } {
				return error("Can't have more than one output node")
			}
			output = node
		}
	}
	if output == unsafe { nil } {
		return error("No output node in graph")
	}
	return output
}

pub fn get_pin_variable(pin &UIPin) string {
	return "var_${pin.uid}"
}


pub fn get_cl_source_code(node_graph &Graph[Node]) !string {
	mut lines := []string{}
	mut visited := []&UINode[Node]{}
	output_node := get_output_node(node_graph) or { return error("Error while starting compilation at output node : ${err}") }
	mut todo := []&UINode[Node]{}
	todo << output_node
	mut depth := 0
	
	graph_output_pin := &UIPin{
		uid:               u64(0)
		name:              "output"
		color:             Color.hex("#000000")
		is_input:          false
	}

	for todo.len > 0 {
		current_todo := todo.clone()
		todo.clear()
		for node in current_todo {
			if visited.contains(node) { continue }
			mut variables := []string{}
			for pin in node.get_input_pins() {
				if pin.is_connected {
					connection := node_graph.get_connections_at_pin(pin)[0] or { return error("Can't find connection to a pin marked as connected") }
					left_node := connection.get_input_node()
					variable_name := get_pin_variable(connection.get_input_pin())
					todo << left_node
					variables << variable_name
				} else if pin.custom_value != none {
					custom_value := pin.custom_value.get_value_str()
					variables << "${custom_value}"
				} else {
					println("Warning at pin ${pin.uid} : No default value for pin found, '0' is used isntead")
					variables << "0"
				}
			}
			output_pin := node.get_output_pins()[0] or { graph_output_pin }
			output_var := get_pin_variable(output_pin)
			str_vars := join_arr(variables, ", ")
			
			line := if node.data.is_custom_var {
				"\t${node.data.return_type} ${output_var} = ${node.data.fn_name};"
			} else {
				"\t${node.data.return_type} ${output_var} = ${node.data.fn_name}(${str_vars});"
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



pub fn get_all_used_functions(node_graph Graph[Node]) string {
	mut fns := []string{}
	for node in node_graph.nodes {
		if node.data.no_compile { continue }
		if fns.contains(node.data.function) { continue }
		fns << node.data.function
	}
	return join_arr(fns, "\n\n")
}



