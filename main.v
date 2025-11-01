module main

import gg
import time
import math
import os
// import stbi

import graph { Graph }
import std { Color }
import std.geom2 { Vec2 }
import std.geom3 { Vec3 }
import objects { Node, NodeArgument }


const window_width = 1600
const window_height = 900
const chunk_size = 1
const camera_move_speed = 40.0
const camera_turn_speed = 0.6

const cl_shader_fn_replace_keyword := "//@FUNCTIONS_HERE"
const cl_shader_map_replace_keyword := "//@MAP_SRC_HERE"


@[heap]
pub struct App {
	pub mut:
	ctx                &gg.Context       = unsafe { nil }
	time               f64
	down_sampling      int               = 3
	frame_timer        time.StopWatch    = time.new_stopwatch()
	delta              f64               = 1.0
	
	renderer           Renderer          = Renderer{}
	camera             Camera            = Camera{pos: Vec3{0, 4, -5}}
	
	node_graph_split   f64               = 0.5 // 0 is full node graph
	node_graph         Graph[Node]       = Graph[Node]{}
	nodes              []Node            = []Node{}
}


pub fn (mut app App) init() {
	// Init nodes to draw
	app.nodes.add_from_json("${@VMODROOT}/objects/objects.json") or { panic("Can't create nodes from json file : ${err}") }
	// > Custom p node
	app.nodes << Node{
		category:         .traffic
		sub_category:     "input"
		name:             "P"
		function:         ""
		icon:             "p"
		
		fn_name:          "p"
		return_type:      "float3"
		return_alias:     ""
		is_custom_var:    true
	}
	// > Custom time node
	app.nodes << Node{
		category:         .traffic
		sub_category:     "input"
		name:             "Time"
		function:         ""
		icon:             "time"
		
		fn_name:          "time"
		return_type:      "float"
		return_alias:     ""
		is_custom_var:    true
	}
	// > Custom output node
	app.nodes << Node{
		category:         .traffic
		sub_category:     "output"
		name:             "Output"
		function:         "output_return"
		icon:             "output"
		
		fn_name:          ""
		return_type:      "return"
		return_alias:     ""
		args:             [NodeArgument{
			name:             "Sample"
			typ:              "float8"
			alias:            "Sample"
		}]
		no_compile:       true
	}
	
	// Create matching UINode for every valid Node
	for node in app.nodes {
		app.node_graph.set_node_selection(node.get_ctx_path("/"), node2uinode(node))
	}
	
	app.node_graph.toast("Welcome", .hint)
	
	// Init renderer
	app.renderer.init() or {
		println("Can't init kernel : ${err}")
		return
	}
	// Init streaming image
	app.renderer.resize(mut app.ctx, window_width, window_height)
}

pub fn (mut app App) frame() {
	// Stopwatch to calculate frame time
	sw := time.new_stopwatch()
	
	// If neccesary, resize streaming image
	window_size := app.ctx.window_size()
	mut target_image_size := Vec2{ window_size.width, f64(window_size.height) * app.node_graph_split }
	target_image_size.x = math.ceil(target_image_size.x / f64(app.down_sampling))
	target_image_size.y = math.ceil(target_image_size.y / f64(app.down_sampling))
	if app.renderer.width != target_image_size.x || app.renderer.height != target_image_size.y {
		app.renderer.resize(mut app.ctx, int(target_image_size.x), int(target_image_size.y))
	}
	
	// Update camera
	app.camera.update(camera_move_speed, app.delta)
	
	// Update image
	app.renderer.run_raymarching(mut app.ctx, app.camera) or {
		println("Can't run raymarching script : ${err}")
		return
	}
	
	app.ctx.begin()
	
	// Draw image
	if app.renderer.image_id == -1 {
		app.ctx.draw_text_default(20, 20, 'No valid image to draw')
	} else {
		app.ctx.draw_image_by_id(
			f32(0), f32(0),
			f32(int(target_image_size.x * f64(app.down_sampling))), f32(int(target_image_size.y * f64(app.down_sampling))),
			app.renderer.image_id
		)
		
		t := if sw.elapsed().milliseconds() != 0 { sw.elapsed().milliseconds() } else { 1 }
		app.ctx.draw_text(20, 20, "FPS : ${1_000 / t}", size: 20, color: gg.white)
		app.ctx.draw_text(20, 40, "render time : ${sw.elapsed().milliseconds()} ms", size: 20, color: gg.white)
		app.ctx.draw_text(20, 60, "downsampling : ${app.down_sampling} x", size: 20, color: gg.white)
	}
	
	// Draw Graph
	app.node_graph.pos =  Vec2{0,                      f64(window_size.height) * app.node_graph_split}
	app.node_graph.size = Vec2{f64(window_size.width), f64(window_size.height) * (1.0 - app.node_graph_split)}
	app.ctx.draw_rect_filled(
		int(app.node_graph.pos.x), int(app.node_graph.pos.y),
		int(app.node_graph.size.x), int(app.node_graph.size.y),
		Color.hex("#232323").get_gx()
	)
	app.node_graph.draw(mut app.ctx)
	
	app.ctx.end()
	
	// Update frame timer
	app.delta = app.frame_timer.elapsed().seconds()
	app.frame_timer.restart()
}


pub fn (mut app App) event(event &gg.Event, _ voidptr) {
	app.node_graph.event(event, mut app.ctx)
	app.camera.react_to_event(event, camera_turn_speed)
	
	if event.typ == .key_down {
		// Recompile
		if event.key_code == .f5 {
			source := app.build_source() or {
				println("Can't build source : ${err}")
				last_err := "${err}".all_after_last(" : ")
				// app.node_graph.toast("Can't build source code : ${err}".replace(" : ", "\n"), .error)
				app.node_graph.toast("Can't build source code\n${last_err}", .error)
				return
			}
			
			app.renderer.recompile(source) or {
				println("Can't recompile shader : ${err}")
				last_err := "${err}".all_after_last(" : ")
				// app.node_graph.toast("Can't recompile shader : ${err}".replace(" : ", "\n"), .error)
				app.node_graph.toast("Can't build source code\n${last_err}", .error)
				return
			}
		}
		
		// Upsample
		if event.key_code == .left_bracket {
			if app.down_sampling > 1 { app.down_sampling -= 1 }
		}
		
		// Downsample
		if event.key_code == .right_bracket {
			if app.down_sampling < 8 { app.down_sampling += 1 }
		}
	}
}


pub fn (app App) build_source() !string {
	// source := get_cl_source_code(&app.node_graph) or { return error("Error while compiling source code : ${err}") }
	// println(source)
	mut base_source := os.read_file(os.join_path("${@VMODROOT}", "shader/raymarching_fast.cl")) or { return error("Can't read base shader source : ${err}") }
	used_fns := get_all_used_functions(app.node_graph)
	map_source := get_cl_source_code(&app.node_graph) or {
		return error("Can't convert graph to lines of code : ${err}")
		// "\treturn (float8)(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f);"
	}
	
	if !base_source.contains(cl_shader_fn_replace_keyword) {
		return error("Invalid base cl shader : No place found for functions from graph -> Add ${cl_shader_fn_replace_keyword}")
	}
	if !base_source.contains(cl_shader_map_replace_keyword) {
		return error("Invalid base cl shader : No place found for map function source code -> Add ${cl_shader_map_replace_keyword}")
	}
	
	base_source = base_source.replace_once(cl_shader_fn_replace_keyword, used_fns)
	base_source = base_source.replace_once(cl_shader_map_replace_keyword, map_source)
	
	if $d("save_cl_build", false) {
		save_path := os.join_path("${@VMODROOT}", "compiled_shader.cl")
		os.write_file(save_path, base_source) or { return error("Can't save compiled shader to file at '${save_path}'") }
	}
	
	return base_source
	// return error("TODO : Reimplimentation of the building of the source code")
}


pub fn (mut app App) cleanup() {
	app.renderer.cleanup(mut app.ctx)
}



fn main() {
	mut app := &App{}
	app.ctx = gg.new_context(
        bg_color:     gg.rgba(255, 0, 255, 1)
        width:        1600
        height:       900
		sample_count: 4
        window_title: 'SDF'
		user_data:    app
        frame_fn:     app.frame
		init_fn:      app.init
		event_fn:     app.event
		cleanup_fn:   app.cleanup
    )
    app.ctx.run()
}