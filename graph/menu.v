module graph

import gg
import sokol.sapp

import std { Color }
import std.geom2 { Vec2 }

pub struct MenuStyle {
	pub mut:
	bg_color             Color           = Color.hex("#333333dd")
	bg_color_hover       Color           = Color.hex("#666666dd")
	text_color           Color           = Color.hex("#ffffff")
	option_size          f64             = 20.0
	option_padding       f64             = 6.0
	option_rounding      f64             = 2.0
	text_size            int             = 14
	min_width            f64             = 80.0
	selection_padding    f64             = 10.0
}

pub struct Menu {
	pub mut:
	delimiter            string          = "/"
	options              []string
	focus                string
	selection            string
	visible              bool
	
	pos                  Vec2
	
	style                MenuStyle       = MenuStyle{}
}

struct UIOption {
	pub mut:
	path                 string
	from                 Vec2
	to                   Vec2
}

pub fn (menu Menu) draw(mut ctx gg.Context) {
	if !menu.visible { return }
	
	for opt in menu.get_ui_options(mut ctx) {
		sub := menu.split_path(opt.path.trim_string_right(menu.delimiter)).last()
		
		// Check, if the option is the hovered one by checking, if the hovered path starts with the option path, or in the case of same depth, if it is the same path
		mut focused := menu.focus.trim_string_left(menu.delimiter).starts_with(opt.path.trim_string_left(menu.delimiter))
		if focused && menu.focus.trim_string_left(menu.delimiter).count(menu.delimiter) == opt.path.trim_string_left(menu.delimiter).count(menu.delimiter) {
			if menu.focus.trim_string_left(menu.delimiter) != opt.path.trim_string_left(menu.delimiter) {
				focused = false
			}
		}
		
		ctx.draw_rounded_rect_filled(
			f32(opt.from.x), f32(opt.from.y),
			f32(opt.to.x - opt.from.x), f32(menu.style.option_size),
			f32(menu.style.option_rounding),
			if focused { menu.style.bg_color_hover.get_gx() } else { menu.style.bg_color.get_gx() }
		)
		
		ctx.draw_text_default(
			int(opt.from.x + menu.style.option_padding),
			int(opt.from.y + menu.style.option_size * 0.5),
			sub
		)
	}
}

pub fn (mut menu Menu) event(event &gg.Event, mut ctx gg.Context) {
	menu.selection = ""
	if !menu.visible { return }
	
	mpos := Vec2{event.mouse_x, event.mouse_y}
	options := menu.get_ui_options(mut ctx)
	
	for opt in options {
		if opt.from.x <= mpos.x && mpos.x < opt.to.x  &&  opt.from.y <= mpos.y && mpos.y < opt.to.y {
			sapp.set_mouse_cursor(.pointing_hand)
			
			menu.focus = opt.path
			if event.typ == .mouse_down && int(event.mouse_button) == 0b0 {
				menu.selection = opt.path
			}
		}
	}
	
	sp := menu.style.selection_padding
	mut partially_covered := false
	for opt in options {
		if !(opt.from.x - sp > mpos.x || mpos.x > opt.to.x + sp  ||  opt.from.y - sp > mpos.y || mpos.y > opt.to.y + sp) {
			partially_covered = true
			break
		}
	}
	
	if !partially_covered {
		menu.visible = false
		menu.focus = ""
	}
}

pub fn (mut menu Menu) hide() {
	menu.focus = ""
	menu.visible = false
}


fn (menu Menu) get_ui_options(mut ctx gg.Context) []UIOption {
	mut y := 0
	mut xui := 0.0
	mut path := ""
	mut ui_options := []UIOption{}
	
	mut steps := menu.split_path(menu.focus.trim_string_left(menu.delimiter))
	steps << ""
	for i, step in steps {
		sub_options := menu.get_sub_options(path)
		
		// > Set Text style
		ctx.set_text_cfg(
			color:            menu.style.text_color.get_gx()
			size:             menu.style.text_size
			vertical_align:   .middle
		)
		
		// > Determine width of option column
		mut width := 0.0
		for sub in sub_options {
			w := ctx.text_width(sub) + menu.style.option_padding * 2.0
			if w > width { width = w }
		}
		if menu.style.min_width > width {
			width = menu.style.min_width
		}
		
		// > Draw option column
		mut next_y_off := 0
		for j, sub in sub_options {
			// >> Track y offset of focused option
			if step == sub {
				next_y_off = j
			}
			
			// > Draw option
			// TODO : Draw BG of option
			from := menu.pos + Vec2{xui, (y + j) * menu.style.option_size}
			size := Vec2{width, menu.style.option_size}
			p := menu.join_path(path, sub)
			
			ui_options << UIOption{
				from: from
				to: from + size
				path: p
			}
		}
		xui += width
		y += next_y_off
		
		if i == 0 {
			path += step
		} else {
			path += menu.delimiter + step
		}
	}
	
	return ui_options
}

// Retunrs all final options, that start with the given parent
pub fn (menu Menu) get_sub_options(parent string) []string {
	mut sub_options := []string{}
	p := parent.trim_string_right(menu.delimiter).trim_string_left(menu.delimiter)
	for option in menu.options {
		if option.starts_with(p) && option.len > p.len + menu.delimiter.len {
			mut sub_option := option.substr(p.len, option.len)
			if !sub_option.starts_with(menu.delimiter) && p != "" {
				continue
			}
			if parent != "" {
				sub_option = option.substr(p.len + menu.delimiter.len, option.len)
			} else {
				sub_option = option.substr(p.len, option.len)
			}
			s := if sub_option.count(menu.delimiter) > 0 { sub_option.all_before(menu.delimiter) } else { sub_option }
			if !sub_options.contains(s) {
				sub_options << s
			}
		}
	}
	return sub_options
}

fn (menu Menu) join_path(parts ...string) string {
	mut path := ""
	for part in parts {
		p := part.trim_string_left(menu.delimiter).trim_string_right(menu.delimiter)
		path += p + menu.delimiter
	}
	return path.trim_string_right(menu.delimiter)
}

fn (menu Menu) split_path(path string) []string {
	return path.trim_string_right(menu.delimiter).split(menu.delimiter)
}

// Returns the depth of the given path
// "food"          -> depth : 1
// "food/cheese"   -> depth : 2
// ""              -> depth : 0
fn (menu Menu) depth(path string) int {
	p := path.trim_string_right(menu.delimiter)
	if p == "" {
		return 0
	}
	return p.count(menu.delimiter) + 1
}