const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

const ui = @import("ui.zig");

var font: ?*c.TTF_Font = null;
var text_engine: ?*c.TTF_TextEngine = null;

pub fn run_process(std_process_init: std.process.Init) !void {
    const SystemMemory = std.process.totalSystemMemory() catch std.math.maxInt(u64);

    std.debug.print("Total System Memory: {}\n", .{SystemMemory >> 30});

    const allocator = std_process_init.gpa;
    const io = std_process_init.io;

    const argv = [_][]const u8{ "ls", "-la", "./" };

    const result = try std.process.run(allocator, io, .{
        .argv = &argv,
        .max_output_bytes = 1024 * 1024,
    });

    std.debug.print("Result: {}\n", .{result});

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    std.debug.print("Exit Status: {any}\n", .{result.term});
    std.debug.print("--- STDOUT ---\n{s}\n", .{result.stdout});

    if (result.stderr.len > 0) {
        std.debug.print("--- STDERR ---\n{s}\n", .{result.stderr});
    }
}

// @todo: Implement left click
pub fn get_event() ui.event_output {
    var input = ui.events.NoEvent;
    var event: c.SDL_Event = undefined;
    var key_c : u8 = 0;
    while (c.SDL_PollEvent(&event)) {
        switch (event.type) {
            c.SDL_EVENT_QUIT => {
                input = ui.events.Quit;
            },
            c.SDL_EVENT_TEXT_INPUT => {
                const text = event.text.text;
                std.debug.print("Text: {s}\n", .{text});
            },
            c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
                const w = event.window.data1;
                const h = event.window.data2;
                std.debug.print("Window resize {} {}\n", .{w, h});
            },
            c.SDL_EVENT_KEY_DOWN => {
                const key = event.key.key;    
                if( key > 255 ) {}
                else if( @as(u8, @intCast(key)) >= ' ' and @as(u8, @intCast(key)) <= '~') {
                    key_c = @as(u8, @intCast(key));
                } else if( key == c.SDLK_BACKSPACE ) {
                    input = ui.events.Delete;
                }
            },
            else => {},
        }
    }

    return ui.event_output{.event = input, .key = key_c};
}

// const message = it_box.id;
// const text_obj = c.TTF_CreateText(
//     text_engine,
//     font,
//     @ptrCast(message.ptr),
//     @intCast(message.len)
// ) orelse return error.TextCreate;
// defer c.TTF_DestroyText(text_obj);

pub fn get_text_width(Font: ui.text_font) i64 {
    var text_w: c_int = 0;
    var text_h: c_int = 0;
    const c_font: *c.TTF_Text = @ptrCast(@alignCast(Font));
    _ = c.TTF_GetTextSize(c_font, &text_w, &text_h);

    return text_w;
}

pub fn get_text_height(Font: ui.text_font) i64 {
    var text_w: c_int = 0;
    var text_h: c_int = 0;

    const c_font: *c.TTF_Text = @ptrCast(@alignCast(Font));
    _ = c.TTF_GetTextSize(c_font, &text_w, &text_h);

    return text_h;
}

pub fn get_text_size(Font: ui.text_font) ui.vec2 {
    var text_w: c_int = 0;
    var text_h: c_int = 0;
    const c_font: *c.TTF_Text = @ptrCast(@alignCast(Font));

    _ = c.TTF_GetTextSize(c_font, &text_w, &text_h);

    return ui.vec2.init(@as(f32, @floatFromInt(text_w)), @as(f32, @floatFromInt(text_h)));
}

pub fn draw_rect(rect: @Vector(4, f32), color: @Vector(4, f32)) [4]c.SDL_Vertex {
    // v1: Top-Left
    const v1 = c.SDL_Vertex{
        .position = c.SDL_FPoint{ .x = rect[0], .y = rect[1] },
        .color = c.SDL_FColor{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
        .tex_coord = c.SDL_FPoint{ .x = 0, .y = 0 },
    };

    // v2: Top-Right
    const v2 = c.SDL_Vertex{
        .position = c.SDL_FPoint{ .x = rect[0] + rect[2], .y = rect[1] },
        .color = c.SDL_FColor{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
        .tex_coord = c.SDL_FPoint{ .x = 0, .y = 0 },
    };

    // v3: Bottom-Left (Fixed: changed rect1 to rect)
    const v3 = c.SDL_Vertex{
        .position = c.SDL_FPoint{ .x = rect[0], .y = rect[1] + rect[3] },
        .color = c.SDL_FColor{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
        .tex_coord = c.SDL_FPoint{ .x = 0, .y = 0 },
    };

    // v4: Bottom-Right (Fixed: changed v2 to v4 to avoid shadowing)
    const v4 = c.SDL_Vertex{
        .position = c.SDL_FPoint{ .x = rect[0] + rect[2], .y = rect[1] + rect[3] },
        .color = c.SDL_FColor{ .r = color[0], .g = color[1], .b = color[2], .a = color[3] },
        .tex_coord = c.SDL_FPoint{ .x = 0, .y = 0 },
    };

    return [4]c.SDL_Vertex{ v1, v2, v3, v4 };
}

pub fn main(std_process_init: std.process.Init) !void {
    // try run_process(std_process_init);

    const config = std.Thread.SpawnConfig{
        .allocator = std_process_init.gpa,
    };

    _ = try std.Thread.spawn(config, run_process, .{std_process_init});

    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIGH_PIXEL_DENSITY)) {
        std.debug.print("SDL_Init failed: {s}\n", .{c.SDL_GetError()});
        return error.SDLInitFailed;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow("Spinning Square", 800, 600, c.SDL_WINDOW_RESIZABLE);
    if (window == null) {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{c.SDL_GetError()});
        return error.WindowCreationFailed;
    }
    defer c.SDL_DestroyWindow(window);

    const renderer = c.SDL_CreateRenderer(window, null);
    if (renderer == null) {
        std.debug.print("SDL_CreateRenderer failed: {s}\n", .{c.SDL_GetError()});
        return error.RendererCreationFailed;
    }
    defer c.SDL_DestroyRenderer(renderer);

    if (!c.TTF_Init()) {
        std.debug.print("SDL_TTF_INIT failed: {s}\n", .{c.SDL_GetError()});
        return error.SDL_TTF_InitFailed;
    }

    text_engine = c.TTF_CreateRendererTextEngine(renderer) orelse return error.EngineCreate;
    defer c.TTF_DestroyRendererTextEngine(text_engine);

    const font_path = "./assets/ttf/IosevkaNerdFontMono-Regular.ttf";
    const font_file = @embedFile(font_path);

    font = c.TTF_OpenFontIO(c.SDL_IOFromConstMem(@ptrCast(font_file.ptr), font_file.len), true, 16.0);

    if (font == null) {
        std.debug.print("Failed to load font: {s}\n", .{c.SDL_GetError()});
        return error.FontLoadFailed;
    }

    var ui_context = ui.context.init(get_event);
    ui_context.get_text_width = get_text_width;
    ui_context.get_text_height = get_text_height;
    ui_context.get_text_size = get_text_size;

    var textbox : [256]u8 = [_]u8{0} ** 256;
    @memcpy(textbox[0..20], "This in an input box");

    // To use the functions you have to first cast your type:
    // var TextObj : TTF_Text;
    // var font_handle: *ui.Font = @ptrCast(*ui.Font, &TextObj);

    var quit = false;
    while (!quit) {
        var w: i32 = 0;
        var h: i32 = 0;

        var mouse_x : f32 = 0;
        var mouse_y : f32 = 0;
        _ = c.SDL_GetMouseState(&mouse_x, &mouse_y);

        // Clear screen
        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(renderer);

        _ = c.SDL_GetRenderOutputSize(renderer, &w, &h);

        // UI Render
        const input = ui_context.get_event();
        if (input.event == ui.events.Quit) {
            quit = true;
        }
        ui_context.set_event(input);
        ui_context.set_mouse_position(ui.vec2.init(mouse_x, mouse_y));

        ui_context.begin();

        _ = ui_context.window_begin("Hello Window", ui.rect.init(10, 10, @as(f32, @floatFromInt(w)) - 20, @as(f32, @floatFromInt(h)) - 20), ui.layout_options{.NONE=true});

        if (ui_context.button("Execute Yamcs", ui.rect.init(15, 10, 200, 30), @Vector(4, f32){ 0.25, 0.2, 0.2, 1.0 }, ui.layout_options{.DRAW_RECT=true}) == ui.events.LeftClick) {}

        if (ui_context.button("Execute Middleware", ui.rect.init(15, 45, 200, 30), @Vector(4, f32){ 0.25, 0.2, 0.2, 1.0 }, ui.layout_options{.DRAW_RECT=true}) == ui.events.LeftClick) {}

        if (ui_context.button("Execute Grafana", ui.rect.init(15, 80, 200, 30), @Vector(4, f32){ 0.25, 0.2, 0.2, 1.0 }, ui.layout_options{.DRAW_RECT=true}) == ui.events.LeftClick) {}

        if (ui_context.button("Execute GNU Radio", ui.rect.init(15, 115, 200, 30), @Vector(4, f32){ 0.25, 0.2, 0.2, 1.0 }, ui.layout_options{.DRAW_RECT=true}) == ui.events.LeftClick) {}

        if( ui_context.textbox(&textbox, ui.rect.init(15, 150, 200, 30), @Vector(4, f32){ 0.25, 0.2, 0.2, 1.0 }, ui.layout_options{.DRAW_RECT=true}) == ui.events.LeftClick) {
            ui_context.set_focus();
        }
        ui_context.window_end();

        const boxes = ui_context.end();

        for (boxes) |it_box| {
            const bound = @Vector(4, f32){ it_box.bounds.x, it_box.bounds.y, it_box.bounds.w, it_box.bounds.h };
            const verts = draw_rect(bound, it_box.color);
            const idx = @Vector(6, i32){ 0, 1, 2, 2, 1, 3 };

            const message = it_box.id;
            const text_obj = c.TTF_CreateText(text_engine, font, @ptrCast(message.ptr), @intCast(message.len)) orelse return error.TextCreate;
            defer c.TTF_DestroyText(text_obj);

            // 1. Get text dimensions (in pixels)
            var text_w: c_int = 0;
            var text_h: c_int = 0;
            _ = c.TTF_GetTextSize(text_obj, &text_w, &text_h);

            if (!c.SDL_RenderGeometry(renderer, null, &verts[0], 4, &idx[0], 6)) {
                std.debug.print("RenderGeometry failed: {s}\n", .{c.SDL_GetError()});
            }

            // 2. Compute center position
            // bound = [x, y, w, h]
            const center_x = bound[0] + 5; //bound[0] + (bound[2] - @as(f32, @floatFromInt(text_w))) / 2.0;
            const center_y = bound[1] + (bound[3] - @as(f32, @floatFromInt(text_h))) / 2.0;

            // 3. Draw at center (pass renderer)
            _ = c.TTF_DrawRendererText(text_obj, center_x, center_y);
        }
        _ = c.SDL_RenderPresent(renderer);

        c.SDL_Delay(16);
    }
}
