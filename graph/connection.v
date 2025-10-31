module graph


pub struct GraphConnection {
	pub mut:
	from              &GraphPin           = unsafe { nil }
	to                &GraphPin           = unsafe { nil }
}

pub fn (connection GraphConnection) is_valid() bool {
	return connection.from != connection.to
}

