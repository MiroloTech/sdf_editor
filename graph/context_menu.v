module graph

import gg
import std.geom2 { Vec2 }
import std { Color }

pub const option_delimiter = "."
pub const option_spacer = "---"

pub struct ContextMenu {
	pub mut:
	options          []string
	selected         string
	selected_path    string
	focused          string
	focused_path     string
	
	pos              Vec2
	visible          bool
}

pub fn ContextMenu.new(options []string) ContextMenu {
	return ContextMenu{
		options: options
	}
}

pub fn (mut menu ContextMenu) add_option(path string) {
	menu.options << path
}

// Returns all next-layer options after the given path
pub fn (menu ContextMenu) get_sub_options(path string) []string {
	mut tags := []string{}
	if path == "" {
		for option in menu.options {
			tag := option.split(option_delimiter)[0]
			if !(tag in tags) {
				tags << tag
			}
		}
		return tags
	}
	
	for option in menu.options {
		if !option.starts_with(path) { continue }
		_ := option.index_after(option_delimiter, path.len) or { continue }
		from := if path.ends_with(option_delimiter) { path.len } else { path.len + option_delimiter.len }
		to := option.index_after(option_delimiter, from) or { option.len }
		if to <= from { continue }
		tag := option.substr(from, to)
		if !(tag in tags) {
			tags << tag
		}
	}
	return tags
}

// Returns true, if the path has any options after it
pub fn (menu ContextMenu) has_next_options(path string) bool {
	return menu.get_sub_options(path).len > 0
}

pub fn (menu ContextMenu) get_index(path string) int {
	if path == "" {
		return 0
	}
	parent := if path.contains(option_delimiter) { path.all_before_last(option_delimiter) } else { "" }
	for i, sub_option in menu.get_sub_options(parent) {
		test_path := if parent == "" { sub_option } else { parent + option_delimiter + sub_option }
		if test_path == path {
			return i
		}
	}
	return 0
}

pub fn (menu ContextMenu) draw(mut ctx gg.Context, style Style) {
	if !menu.visible { return }
	
	mut x := 0.0
	mut index_off := 0
	mut folders := menu.focused_path.split(option_delimiter)
	if folders[0] != "" {
		folders.prepend("")
	}
	mut host_path := ""
	for folder in folders {
		host_path += if host_path == "" { folder } else { option_delimiter + folder }
		index := index_off + menu.get_index(host_path)
		sub_options := menu.get_sub_options(host_path)
		
		// > Draw BG
		ctx.draw_rounded_rect_filled(
			f32(menu.pos.x + x), f32(menu.pos.y + style.ctx_menu_option_height * f64(index)),
			f32(style.ctx_menu_width), f32(style.ctx_menu_option_height * f64(sub_options.len)),
			f32(style.ctx_menu_rounding),
			style.ctx_menu_color.get_gx()
		)
		
		// > Draw options
		for i, option in sub_options {
			path := if host_path == "" { option } else { host_path + option_delimiter + option }
			yoff := style.ctx_menu_option_height * 0.5
			
			// >> Draw hovering rect
			if menu.focused_path.starts_with(path + option_delimiter) || path == menu.focused_path {
				ctx.draw_rounded_rect_filled(
					f32(menu.pos.x + x), f32(menu.pos.y + style.ctx_menu_option_height * f64(i + index)),
					f32(style.ctx_menu_width), f32(style.ctx_menu_option_height),
					f32(style.ctx_menu_rounding),
					Color.hex("#ffffff22").get_gx()
				)
			}
			
			ctx.draw_text(
				int(menu.pos.x + x + style.ctx_menu_padding), int(menu.pos.y + style.ctx_menu_option_height * f64(i + index) + yoff),
				option.title(),
				max_width:       int(style.ctx_menu_width)
				color:           style.text_color.get_gx()
				vertical_align:  .middle
				size:            int(style.ctx_menu_option_height - style.ctx_menu_padding)
			)
			
			if menu.has_next_options(path) {
				tri_pos := Vec2{
					menu.pos.x + x + style.ctx_menu_width - style.ctx_menu_padding,
					menu.pos.y + style.ctx_menu_option_height * f64(i + index) + yoff
				}
				tri_size := (style.ctx_menu_option_height - style.ctx_menu_padding * 2.0) * 0.3
				ctx.draw_triangle_filled(
					f32(tri_pos.x - tri_size), f32(tri_pos.y - tri_size),
					f32(tri_pos.x), f32(tri_pos.y),
					f32(tri_pos.x - tri_size), f32(tri_pos.y + tri_size),
					style.text_color.get_gx()
				)
			}
		}
		x += style.ctx_menu_width
		index_off = index
	}
}

pub fn (mut menu ContextMenu) event(event &gg.Event, style Style) {
	if event.typ == .mouse_move {
		mpos := Vec2{event.mouse_x, event.mouse_y}
		mut x := 0.0
		mut folders := menu.focused_path.split(option_delimiter)
		if folders[0] != "" {
			folders.prepend("")
		}
		
		menu.focused_path = ""
		mut host_path := ""
		mut index_off := 0
		for folder in folders {
			host_path += if host_path == "" { folder } else { option_delimiter + folder }
			index := index_off + menu.get_index(host_path)
			sub_options := menu.get_sub_options(host_path)
			// println(folders)
			
			// > Draw options
			mut is_final := false
			for i, option in sub_options {
				path := if host_path == "" { option } else { host_path + option_delimiter + option }
				pos := Vec2{ menu.pos.x + x, menu.pos.y + style.ctx_menu_option_height * f64(i + index) }
				size := Vec2{ style.ctx_menu_width, style.ctx_menu_option_height }
				if pos.x <= mpos.x && mpos.x < pos.x + size.x  &&  pos.y <= mpos.y && mpos.y < pos.y + size.y {
					is_final = true
				}
				if is_final {
					menu.focused_path = path //  if menu.focused_path == "" { option } else { option_delimiter + option }
					break
				}
			}
			if is_final {
				break
			}
			x += style.ctx_menu_width
			index_off = index
		}
		
		if menu.focused_path == "" {
			menu.selected = ""
			menu.selected_path = ""
			menu.visible = false
		}
	}
	
	if event.typ == .mouse_down {
		if menu.focused_path != "" && !menu.has_next_options(menu.focused_path) {
			menu.selected_path = menu.focused_path
			menu.selected = menu.focused_path.split(option_delimiter).last()
			println("Selceted : ${menu.selected} at ${menu.selected_path}")
		}
	}
	
	if event.typ == .mouse_up && menu.selected_path != "" {
		menu.selected = ""
		menu.selected_path = ""
		menu.focused_path = ""
		menu.visible = false
	}
}
