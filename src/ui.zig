const std = @import("std");

pub const STACK_SIZE  : u64 = 2056;
pub const MAX_BOX_SIZE: u64 = 6 << 10;

pub fn stack_init(comptime value_type: type, comptime capacity: usize) type {
    return struct {
        value: [capacity]value_type,
        current: usize = 0,

        const Self = @This();

        /// Create and initialize a new stack.
        pub fn init() Self {
            var self: Self = undefined;
            // Zero-init current (value is undefined OK for stack)
            self.current = 0;
            return self;
        }

        /// Reset to empty (call before each frame).
        pub fn reset(self: *Self) void {
            self.current = 0;
        }

        /// Push item (silent overflow ignore; add @panic() if desired).
        pub fn push(self: *Self, item: value_type) void {
            if (self.current < self.value.len) {
                self.value[self.current] = item;
                self.current += 1;
            }
        }

        /// Pop (decrements index; doesn't free data).
        pub fn pop(self: *Self) void {
            if (self.current > 0) {
                self.current -= 1;
            }
        }

        /// Top item (null if empty).
        pub fn get_front(self: *Self) *value_type {
            if (self.current >= 0) {
            	return &self.value[self.current - 1];
        	}
        }

        /// View of used items (for `end()`).
        pub fn items(self: *const Self) []const value_type {
            return self.value[0..self.current];
        }
    };
}

pub const rect = struct {
	x : f32,
	y : f32,
	w : f32,
	h : f32,

	pub fn init(x : f32, y: f32, w : f32, h : f32 ) rect {
		return rect {
			.x = x, .y = y, .w = w, .h = h
		};
	}
};

pub const vec2 = struct {
	x : f32,
	y : f32,

	pub fn init(x : f32, y : f32) vec2 {
		return vec2 {
			.x = x,
			.y = y,
		};
	}

	pub fn dot(self: vec2, other: vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn add(self: vec2, other: vec2) vec2 {
        return vec2{
        	.x = self.x + other.x,
        	.y = self.y + other.y,
        };
    }
    pub fn res(self: vec2, other: vec2) vec2 {
        return vec2{
        	.x = self.x - other.x,
        	.y = self.y - other.y,
        };
    }
};

pub const layout_options = packed struct(u11) {
    NONE : bool = false,
	ALIGN_CENTER : bool = false,
	ALIGN_RIGHT : bool = false,
	ACTION_ON_CLICK : bool = false,
	ACTION_ON_RELEASE : bool = false,
	BORDERLESS : bool = false,
	RESIZABLE : bool = false,
	DRAW_RECT : bool = false,
	DRAW_BORDER : bool = false,
	DRAW_TEXT : bool = false,
	INPUT_TEXT : bool = false,
};

pub const box = struct {
	id     : []const u8,
	bounds : rect,
	color  : @Vector(4, f32),
	options : layout_options,
};

pub const layout = struct {
	bounds  : rect,
	content : rect,
	default_options : layout_options,
};

pub const layout_stack = stack_init(layout, STACK_SIZE);
pub const box_stack    = stack_init(box   , MAX_BOX_SIZE);
pub const parent_stack = stack_init(*box  , STACK_SIZE);

pub const events = enum(u32) {
	NoEvent,
	LeftClick,
	RightClick,
	MiddleClick,
	Delete,
	ScrollUp,
	ScrollDown,
	Enter,
	Quit
};

pub const event_output = struct {
	event : events,
	key   : u8
};

pub const text_engine = *anyopaque;
pub const text_font = *anyopaque;

pub const context = struct {
	layouts : layout_stack,
	boxes : box_stack,

	input : events,
	cursor_pos: vec2,

	font_engine : text_engine = undefined,
	font_data : text_font     = undefined,

	input_text : [256]u8 = undefined,
	input_idx  : usize,

	current_event : event_output,

	get_event: *const fn () event_output,

	get_text_width : ?*const fn (f : text_font) i64 = null,
	get_text_height: ?*const fn (f : text_font) i64 = null,
	get_text_size  : ?*const fn (f : text_font) vec2 = null,

	parents : parent_stack,

	focus_box: *box,

	pub fn init(get_event: *const fn () event_output) context {
	    return .{
	        .input = events.NoEvent,
	        .cursor_pos = .{ .x = 0, .y = 0 },
	        .layouts = layout_stack.init(),
	        .boxes = box_stack.init(),
	        .get_event = get_event,
	        .parents = parent_stack.init(),
	        .input_idx = 0,
	        .focus_box = undefined,
	        .current_event = event_output{.event = events.NoEvent, .key = 0}
	    };
	}
	
	pub fn begin(self: *context) void {
		self.input = events.NoEvent;
		self.layouts.reset();
		self.boxes.reset();
		self.parents.reset();
	}

	pub fn end(self: *context) []box {
		return self.boxes.value[0..self.boxes.current];
	}

	pub fn window_begin(self: *context, id : []const u8, win_size : rect, options : layout_options) bool {
		const new_box = box{
			.id = id,
			.bounds = win_size,
			.color  = @Vector(4, f32){0.15, 0.15, 0.15, 1.0},
			.options = options
		};

		self.boxes.push(new_box);
		self.parents.push(self.boxes.get_front());

		return true;
	}

	pub fn window_end(self: *context) void {

		self.parents.pop();
	}

	pub fn set_focus(self: *context) void {
		self.focus_box = self.boxes.get_front();
	}

	pub fn input_char(self: *context, in: u8) void {
		self.input_text[self.input_idx] = in;
		self.input_idx += 1;
		self.input_text[self.input_idx] = 0;
	}
	pub fn input_delete_char(self: *context) void {
		self.input_text[self.input_idx] = 0;
		self.input_idx -= 1;
	}

	pub fn consume_input(self: *context) void {
		self.input_idx = 0;
		self.input_text[self.input_idx] = 0;
	}

	pub fn set_event(self: *context, event: event_output) void {
		self.current_event = event;
	}

	pub fn is_cursor_over(self: *context, bounds: rect) bool {
		if( self.cursor_pos.x >= bounds.x and self.cursor_pos.x <= (bounds.x + bounds.w)) {
			if( self.cursor_pos.y >= bounds.y and self.cursor_pos.y <= (bounds.y + bounds.h)) {
				return true;
			}
		}

		return false;
	}

	pub fn set_mouse_position(self: *context, pos : vec2) void {
		self.cursor_pos = pos;
	}

	pub fn push_rect(self: *context, bound: rect, color: @Vector(4, f32)) void {
		const new_box = box{
			.id = "rect",
			.bounds = bound,
			.color  = color,
			.options = layout_options{.DRAW_RECT=true},
		};

		self.boxes.push(new_box);
	}

	pub fn button(self: *context, id : []const u8, bound : rect, color : @Vector(4, f32), options : layout_options) events {
		var input : events = events.NoEvent;

		var new_box = box{
			.id = id,
			.bounds = bound,
			.color  = color,
			.options = options,
		};

		new_box.options.DRAW_TEXT = true;

		if( self.is_cursor_over(new_box.bounds) ) {
			input = self.current_event.event;
			new_box.color[0] += 0.1;

			input = self.current_event.event;
		}

		self.boxes.push(new_box);

		return input;
	}

	pub fn label(self: *context, id : []const u8, bound : rect, color : @Vector(4, f32), options : layout_options) events {
		var input : events = events.NoEvent;

		var new_box = box{
			.id = id,
			.bounds = bound,
			.color  = color,
			.options = options,
		};

		new_box.options.DRAW_TEXT = true;

		self.boxes.push(new_box);

		if( self.is_cursor_over(new_box.bounds) or self.boxes.get_front() == self.focus_box) {
			input = self.current_event.event;
		}
		return input;
	}

	/// textbox uses a user-defined textbox, the api is in charge of showing the correct information
	pub fn textbox(self: *context, id : []u8, bound : rect, color : @Vector(4, f32), options : layout_options) events {
		var input : events = events.NoEvent;

		var new_box = box{
			.id = id,
			.bounds = bound,
			.color  = color,
			.options = options,
		};

		new_box.options.DRAW_TEXT = true;
		new_box.options.INPUT_TEXT = true;

		self.boxes.push(new_box);

		if( self.is_cursor_over(new_box.bounds) or self.boxes.get_front() == self.focus_box) {

			self.boxes.get_front().color[3] *= 0.9;
			self.boxes.get_front().color[0] *= 1.1;
			input = self.current_event.event;

            if( self.current_event.key > 255 ) {
            
            } else if( @as(u8, @intCast(self.current_event.key)) >= ' ' and @as(u8, @intCast(self.current_event.key)) <= '~') {
				var current_len: usize = 0;
	            while (current_len < id.len and id[current_len] != 0) : (current_len += 1) {}
	            id[current_len] = self.current_event.key;
	            id[current_len+1] = 0;
			} else if( input == events.Delete) {
	            var current_len: usize = 0;
	            while (current_len < id.len and id[current_len] != 0) : (current_len += 1) {}

	            // 2. If there is text to delete
	            if (current_len > 0) {
	                current_len -= 1;
	                id[current_len] = 0; // Null-terminate at the new position
	            }
			}

			if( input == events.LeftClick ) {
				self.set_focus();
			}
		}

		return input;
	}

	pub fn checkbox(self: *context, id : []const u8, bound : rect, color : @Vector(4, f32), check_confirm : *bool) events {
		var input : events = events.NoEvent;

		const new_box = box{
			.id = id,
			.bounds = bound,
			.color  = color,
			.options = layout_options{.DRAW_RECT = true},
		};

		// new_box.options.DRAW_RECT = true;

		self.boxes.push(new_box);

		if( self.is_cursor_over(new_box.bounds) or check_confirm.* ) {

			var checked_bound = bound;
			checked_bound.x += 2;
			checked_bound.w -= 4;
			checked_bound.y += 2;
			checked_bound.h -= 4;

			var inn_box = box{
				.id = id,
				.bounds = checked_bound,
				.color  = @Vector(4, f32){0.1, 0.25, 0.1, 1.0},
				.options = layout_options{.DRAW_RECT = true},
			};

			inn_box.color[1] += 0.1;

			self.boxes.push(inn_box);

			input = self.current_event.event;

			if( self.is_cursor_over(new_box.bounds) and input == events.LeftClick ) {
				check_confirm.* = !check_confirm.*;
			}
		}

		return input;
	}

	//pub fn begin_scrollview(self: *context) void {}

	//pub fn end_scrollview(self: *context) void {}
}; 
