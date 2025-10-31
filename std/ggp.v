module std

import gg

type StringColChar = Color | string
type StringCol = []StringColChar

pub fn draw_image(mut ctx gg.Context, img Image, x int, y int, width int, height int, img_cfg ImageDrawCfg) {
	// TODO : Optimize Image drawing function
	for xx in x..(x + width) {
		for yy in y..(y + height) {
			// TODO : Add antialiasing
			x_fract := f64(xx - x) / f64(width)
			y_fract := f64(yy - y) / f64(height)
			x_img := int(x_fract * img.width)
			y_img := int(y_fract * img.height)
			
			col := img.get_pixel(x_img, y_img)
			if col.a <= img_cfg.threshhold { continue }
			
			ctx.draw_pixel(xx, yy, col.get_gx())
		}
	}
}

// draw_icon is a specialized function to draw_image, which draws the image with an alpha cut value of 0.5 and a custom fill value
pub fn draw_icon(mut ctx gg.Context, img Image, x int, y int, width int, height int, fill_color Color) {
	// TODO : Optimize Image drawing function
	for xx in x..(x + width) {
		for yy in y..(y + height) {
			// TODO : Add antialiasing
			x_fract := f64(xx - x) / f64(width)
			y_fract := f64(yy - y) / f64(height)
			x_img := int(x_fract * img.width)
			y_img := int(y_fract * img.height)
			
			col := img.get_pixel(x_img, y_img)
			if col.a < 0.5 { continue }
			
			ctx.draw_pixel(xx, yy, fill_color.get_gx())
		}
	}
}

// draw_text_fancy allows you to easily draw text with specific font, coloring and styling options. This is meant to replace the hassle of regularly drawing multi-color and font-specific text
pub fn draw_text_fancy(mut ctx gg.Context, text StringCol, x int, y int, cfg TextCfg) {
	mut currx := 0
	for token in text {
		if token is Color {
			ctx.set_text_cfg(
				color:   token.get_gx()
				size:    cfg.size
				family:  cfg.font_path
				bold:    cfg.bold
				mono:    cfg.mono
				italic:  cfg.italic
			)
		}
		if token is string {
			ctx.draw_text_default(currx + x, y, token)
			currx += ctx.text_width(token)
		}
	}
}

@[params]
pub struct TextCfg {
	pub:
	size                  int
	font_path             string
	bold                  bool
	mono                  bool
	italic                bool
	
	line_spacing          f64
}

@[params]
pub struct ImageDrawCfg {
	pub:
	threshhold          f64          = 0.01        // Threshhold at which drawing the pixel in an image is discarded
}

