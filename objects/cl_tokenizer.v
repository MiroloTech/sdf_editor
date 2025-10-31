module objects
	
pub const special_chars := "(){}[]!@#$%^&*-=+/?<>,:;\"'\t "
pub const excluded_chars := "\t "

pub fn cl_tokenize(text string) []string {
	if text.len == 0 {
		return []string{}
	}

	mut tokens := []string{}

	for i, c8 in text {
		c := c8.ascii_str()
		if tokens.len == 0 {
			if c8 in excluded_chars.bytes() {
				tokens << ""
			} else {
				tokens << c
			}
			continue
		}
		last_token := tokens[tokens.len - 1]
		
		if c8 in special_chars.bytes() {
			if c8 in excluded_chars.bytes() {
				if last_token != "" { tokens << "" }
			} else {
				if last_token == "" {
					tokens[tokens.len - 1] += c
					if i < text.len - 1 {
						tokens << ""
					}
				} else {
					tokens << c
				}
			}
			continue
		}
		
		if last_token.len == 0 {
			tokens[tokens.len - 1] += c
			continue
		}
		if !(last_token[last_token.len - 1] in special_chars.bytes()) {
			tokens[tokens.len - 1] += c
			continue
		}
		tokens << c
	}
	
	return tokens
}
