module objects

import x.json2
import os

import std { Color }

// Basic structure for objects to display in the shader
// (#｀-_ゝ-)  DON'T LOOK AT ME, I'M SOOOO UGLY!!!!!!

pub enum Category {
	other
	math
	math2d
	math3d
	shape
	operator
	constant
	traffic
}

pub const aliases := {
	"Sample" : "float8"
	"Material" : "float8"
}

// These data types are for the opencl byte buffer
// NOTICE : The sizes defined, are the size in the byte array, not the size of the datatype on the GPU
pub const valid_cl_shader_types := {
	"float" :        TypeData{4,    Color.hex("#82bcff"),     1},
	"float2" :       TypeData{8,    Color.hex("#539adb"),     2},
	"float3" :       TypeData{12,   Color.hex("#006ec2"),     3},
	"float4" :       TypeData{16,   Color.hex("#5a7df2"),     4},
	"float8" :       TypeData{32,   Color.hex("#1e55fa"),     8},
	"float16" :      TypeData{64,   Color.hex("#1629f7"),     16},
	"double" :       TypeData{8,    Color.hex("#a8ffc5"),     1},
	"double2" :      TypeData{16,   Color.hex("#48ff00"),     2},
	"double3" :      TypeData{24,   Color.hex("#00cf2d"),     3},
	"double4" :      TypeData{32,   Color.hex("#00ad74"),     4},
	"double8" :      TypeData{64,   Color.hex("#048560"),     8},
	"double16" :     TypeData{128,  Color.hex("#002e22"),     16},
	"int" :          TypeData{4,    Color.hex("#fc6a8c"),     1},
	"int2" :         TypeData{8,    Color.hex("#ff306c"),     2},
	"int3" :         TypeData{12,   Color.hex("#d4135d"),     3},
	"int4" :         TypeData{16,   Color.hex("#ad005f"),     4},
	"int8" :         TypeData{32,   Color.hex("#820153"),     8},
	"int16" :        TypeData{64,   Color.hex("#471425"),     16},
	"short" :        TypeData{16,   Color.hex("#fac3d3"),     1},
	"long" :         TypeData{64,   Color.hex("#6b0425"),     1},
	"bool" :         TypeData{1,    Color.hex("#f018f0"),     1},
	"char" :         TypeData{1,    Color.hex("#f27638"),     1},
	// TODO : Add support for keyword 'unsigned'
	"Environment" :  TypeData{52,   Color.hex("#3c5900"),     1},
	
	// Aliases
	"Material":      TypeData{0,    Color.hex("#ffe74c"),     0},
	"Sample":        TypeData{0,    Color.hex("#28a4bd"),     0},
}

pub const unsupported_clshader_types := {
	"image2d_t" : "image types are not supported for sdf operations",
	"image3d_t" : "image types are not supported for sdf operations",
	"image1d_t" : "image types are not supported for sdf operations",
	"image1d_buffer_t" : "image types are not supported for sdf operations",
	"image1d_array_t" : "image types are not supported for sdf operations",
	"image2d_array_t" : "image types are not supported for sdf operations",
	"image2d_depth_t" : "image types are not supported for sdf operations",
	"image2d_array_depth_t" : "image types are not supported for sdf operations",
	"image2d_msaa_t" : "image types are not supported for sdf operations",
	"image2d_array_msaa_t" : "image types are not supported for sdf operations",
	"image2d_msaa_depth_t" : "image types are not supported for sdf operations",
	"image2d_array_msaa_depth_t" : "image types are not supported for sdf operations",
	
	"half" : "half types are not supported, because they can not be properly converted from a byte array",
	"half2" : "half types are not supported, because they can not be properly converted from a byte array",
	"half3" : "half types are not supported, because they can not be properly converted from a byte array",
	"half4" : "half types are not supported, because they can not be properly converted from a byte array",
	"half8" : "half types are not supported, because they can not be properly converted from a byte array",
	"half16" : "half types are not supported, because they can not be properly converted from a byte array",
}


pub struct TypeData {
	pub mut:
	buff_size    u16          = 1
	color        Color        = Color.hex("#ffffff")
	vector_size  int          = 1
}

pub struct NodeArgument {
	pub:
	name             string
	typ              string
	alias            string
	macros           []string
	
	cl_byte_size     u16
}

pub struct Node {
	pub mut:
	category         Category
	sub_category     string
	name             string
	function         string
	icon             string
	
	fn_name          string
	return_type      string
	return_alias     string
	args             []NodeArgument
	
	// > Compiler stats
	is_custom_var    bool
	no_compile       bool
}

// @[params]
pub struct NodeConfig {
	pub mut:
	category         ?Category
	sub_category     ?string
	name             ?string
	icon             ?string
}

pub fn Node.new(source_code string, config NodeConfig) !Node {
	if source_code == "" {
		return error("Function source code must be provided")
	}
	
	mut node := Node{}
	node.category = config.category or { Category.other }
	node.sub_category = config.sub_category or { "" }
	node.name = config.name or { "" }
	node.icon = config.icon or { "" }
	node.function = source_code
	
	tokens := cl_tokenize(source_code)
	
	// Find first bracket of function to go from there
	mut fn_bracket_token_idx := -1
	mut in_comment := 0 // 0 = no comment, 1 = one-line comment, 2 = multi-line comment
	for i, token in tokens {
		next_token := if i == tokens.len - 1 { "" } else { tokens[i + 1] }
		
		// Manage comments
		if token == "/" && in_comment == 0 {
			if next_token == "/" {
				in_comment = 1
			} else if next_token == "*" {
				in_comment = 2
			}
			continue
		}
		if (token == "\n" && in_comment == 1) || (token == "*" && next_token == "/" && in_comment == 2) {
			in_comment = 0
			continue
		}
		
		if token == "(" {
			if i < 2 {
				return error("Function source code either misses function name, return type or both")
			}
			fn_bracket_token_idx = i
			break
		}
	}
	in_comment = 0
	if fn_bracket_token_idx == -1 {
		return error("Function not found")
	}
	
	// Extract function name and return type
	fn_name := tokens[fn_bracket_token_idx - 1]
	mut return_type := tokens[fn_bracket_token_idx - 2]
	return_type = verify_cl_type(return_type) or { return error("Function returns ${err}") }
	if return_type != tokens[fn_bracket_token_idx - 2] {
		node.return_alias = tokens[fn_bracket_token_idx - 2]
	}
	
	// Extract arguments for function
	mut args := []NodeArgument{}
	mut active_type := ""
	mut active_alias := ""
	mut active_name := ""
	mut active_macros := []string{}
	for i in (fn_bracket_token_idx + 1)..(tokens.len) {
		token := tokens[i].replace("\t", "").replace("\n", "")
		if token == "" || !token.is_pure_ascii() || token.is_blank() { continue }
		if token == "," || token == ")" {
			if active_type == "" {
				return error("Function argument type not provided")
			}
			if active_name == "" {
				return error("Function argument name not provided")
			}
			args << NodeArgument{
				name:          active_name,
				typ:           active_type,
				alias:         active_alias,
				macros:        active_macros,
				cl_byte_size:  valid_cl_shader_types[active_type].buff_size
			}
			active_type = ""
			active_alias = ""
			active_name = ""
			active_macros = []string{}
			if token == "," { continue }
		}
		if token == ")" {
			break
		}
		if token.starts_with("__") {
			active_macros << token
			continue
		}
		
		if active_type == "" {
			active_type = token
			if active_type in aliases {
				active_alias = active_type
			}
			active_type = verify_cl_type(active_type) or { return error("Function argument is an ${err}") }
			continue
		}
		if active_name == "" {
			active_name = token
			continue
		}
		mut err_token_arr := tokens.clone()
		err_token_arr.drop(fn_bracket_token_idx)
		err_token_arr.trim(i)
		return error("Invalid argument definition in function : ${err_token_arr} -> next token : ${token}")
	}
	
	node.fn_name = fn_name
	node.return_type = return_type
	node.args = args
	
	if node.name == "" {
		node.name = fn_name.title()
	}
	
	return node
}

// Returns error, if the given typ is invalid, and returns the correct type name, when the type matches up with an alias
fn verify_cl_type(typ string) !string {
	mut t := typ
	if t in aliases {
		t = aliases[typ]
	}
	if t in unsupported_clshader_types {
		err := unsupported_clshader_types[t]
		return error("unsupported type '${typ}' : ${err}")
	}
	if !(t in valid_cl_shader_types.keys()) {
		return error("invalid type : ${typ}")
	}
	return t
}


// Adds nodes, registered in the .json file, to the given array of nodes
pub fn (mut nodes []Node) add_from_json(path string) ! {
	json_source := os.read_file(path) or { return error("Can't open json file : ${err}") }
	raw_json := json2.raw_decode(json_source) or { return error("Can't decode given json file at '${path}' : ${err}") }
	for i, json_arr_element in raw_json.arr() {
		json_data := json_arr_element.as_map_of_strings()
		
		// > Reading source code
		mut source_code := ""
		if "source_code" in json_data.keys() {
			source_code = json_data["source_code"]
		} else if "source_path" in json_data.keys() {
			// >> Get path and selected lines
			mut real_source_path := json_data["source_path"].split(":")[0] or { json_data["source_path"] }
			real_source_path = real_source_path.replace("@LOCAL", @VMODROOT)
			line_range := json_data["source_path"].split(":")[1] or { "" }
			
			source_code_raw := os.read_file(real_source_path) or { return error("Invalid source code path for node given : ${real_source_path}") }
			
			// > Write file or section of file, depending on the ginve line range
			if line_range == "" {
				source_code = source_code_raw
			} else {
				if !line_range.contains("-") {
					return error("Given line range in json file at node number '${i}' from json file '${path}' must contain two numbers, split by '-'")
				}
				
				line_from := (line_range.split("-")[0] or { return }).int()
				line_to := (line_range.split("-")[1] or { "${line_from}" }).int()
				mut current_line := 1
				for c8 in source_code_raw {
					c := c8.ascii_str()
					if c == "\n" {
						current_line++
					}
					if current_line >= line_from && current_line <= line_to {
						source_code += c
					}
					if current_line > line_to {
						break
					}
				}
			}
		}
		
		// > Constructing and adding node
		node := Node.new(
			source_code,
			category:         Category.from(json_data["category"] or { "" }) or { Category.other }
			sub_category:     json_data["sub_category"] or { "" }
			name:             json_data["name"] or { "" }
			icon:             json_data["sub_category"] or { "" }
		) or { return error("Couldn't create node number '${i}' from json file '${path}' : ${err}") }
		nodes << node
	}
}

pub fn (node Node) get_ctx_path() string {
	return if node.sub_category == "" {
		node.category.str() + "." + node.name
	} else {
		node.category.str() + "." + node.sub_category + "." + node.name
	}
}

