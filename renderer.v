module main

import gg                  // Updating / Creating streaming images for display
import vsl.vcl             // Running OpenCL scripts
import time                // Timing kernel execution
import os                  // Reading OpenCL file source
import math                // Deg to Rad calculations

const root = os.dir(@FILE)
const kernels_dir = os.join_path(root, 'shader')
const kernel_name := "raymarching_fast"

struct CLFloat4 {
	pub mut:
	x   f32
	y   f32
	z   f32
	w   f32
}

pub struct Renderer {
	pub mut:
	device            &vcl.Device       = unsafe { nil }
	kernel            &vcl.Kernel       = unsafe { nil }
	image_id          int               = -1
	width             int
	height            int
	is_free           bool              = true
	
	timer             time.StopWatch    = time.new_stopwatch()
	frames            u64
	avg_frame_time    f64
}


// Run once to initialize the renderer and all OpenCL-related objects
pub fn (mut renderer Renderer) init() ! {
	// Load source code
	source := os.read_file(os.join_path(kernels_dir, '${kernel_name}.cl')) or { return error("Can't read kernel source : ${err}") }
	
	// Find appropriate OpenCL device
	devices := vcl.get_devices(.all) or { return error("Can't get compute devices : ${err}") }
	if devices.len == 0 { return error("No compute devices found") }
	
	renderer.device = devices[0]
	println("Available devices : ${devices}")
	println("Rendering on '${renderer.device}'")
	
	// Add program source to device and define kernel
	renderer.device.add_program(source) or { return error("Can't add compute program to device : ${err}") }
	renderer.kernel = renderer.device.kernel('${kernel_name}') or { return error("Can't load kernel on device : ${err}") }
}

// Recompiles the shader source
pub fn (mut renderer Renderer) recompile(source string) ! {
	renderer.device.release() or { return error("Can't release old device : ${err}") }
	
	devices := vcl.get_devices(.all) or { return error("Can't get compute devices : ${err}") }
	if devices.len == 0 { return error("No compute devices found") }
	
	renderer.device = devices[0]
	println("Recompiling to '${renderer.device}'")
	
	renderer.device.add_program(source) or { return error("Can't add compute program to device : ${err}") }
	renderer.kernel = renderer.device.kernel('${kernel_name}') or { return error("Can't load kernel on device : ${err}") }
	
	renderer.timer = time.new_stopwatch()
}

// Runs the kernel, defined in the renderer, built for calling every frame to update the main image
pub fn (mut renderer Renderer) run_raymarching(mut ctx gg.Context, cam Camera) ! {
	renderer.is_free = false
	// Start stopwatch
	sw := time.new_stopwatch()
	
	// Create image buffer (image2d_t) for kernel execution
	mut kernel_img := renderer.device.image(.rgba, width: renderer.width, height: renderer.height) or {
		return error("Can't create image buffer : ${err}")
	}
	
	// Collect camera data
	cam_dir := cam.get_dir()
	
	// Run kernel
	kernel_err := <- (renderer.kernel).global(int(renderer.width), int(renderer.height))
		.local(1, 1).run(
			kernel_img,
			f32(cam.fov) * (math.pi / 180.0),
			f32(cam.pos.x), f32(cam.pos.y), f32(cam.pos.z),
			f32(cam_dir.x), f32(cam_dir.y), f32(cam_dir.z),
			f32(renderer.timer.elapsed().seconds())
		)
	if kernel_err !is none {
		return error("Can't run kernel : ${kernel_err}")
	}
	
	// Get image data from buffer and update gg streaming image
	img_data := kernel_img.data() or { return error("Can't get data from kernel image after running kernel : ${err}") }
	ctx.update_pixel_data(renderer.image_id, img_data.data)
	
	// Release image
	kernel_img.release() or { return error("Can't release kernel image after running kernel : ${err}") }
	renderer.frames++
	
	// Debug print runtime of the kernel
	if $d("debug-time", false) {
		println('Frame time : ${sw.elapsed().milliseconds()} ms  :  frame ${renderer.frames}')
		renderer.avg_frame_time += f64(sw.elapsed().milliseconds()) / 1000.0
		
		if renderer.frames % 20 == 0 {
			renderer.avg_frame_time /= 20.0
			renderer.avg_frame_time *= 1000.0
			println("Avg frame time : ${int(renderer.avg_frame_time)}")
			renderer.avg_frame_time = 0.0
		}
	}
	renderer.is_free = true
}


// cleans up opencl objects and the streaming image
pub fn (mut renderer Renderer) cleanup(mut ctx gg.Context) {
	if renderer.image_id != -1 {
		ctx.remove_cached_image_by_idx(renderer.image_id)
	}
	if renderer.device != unsafe { nil } {
		renderer.device.release() or {
			println("Can't release device : ${err}")
			return
		}
	}
}



// Reloads or creates the streaming image used for displaying the output of the kernel
pub fn (mut renderer Renderer) recreate_gg_streaming_image(mut ctx gg.Context, width int, height int) {
	if renderer.image_id != -1 {
		ctx.remove_cached_image_by_idx(renderer.image_id)
	}
	// println("Creating new streaming image ${width}x${height}")
	renderer.image_id = ctx.new_streaming_image(
		width,
		height,
		4,
		pixel_format: .rgba8
	)
	renderer.width = width
	renderer.height = height
}



// Resizes renderer's width and height and the gg streaming image
pub fn (mut renderer Renderer) resize(mut ctx gg.Context, width int, height int) {
	renderer.width = width
	renderer.height = height
	
	renderer.recreate_gg_streaming_image(mut ctx, width, height)
}
