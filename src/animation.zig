// PORT TO ZIG of https://rxi.github.io/a_simple_ui_animation_system.html

const std = @import("std");

const ANIMATION_MAX_ITEMS: i64 = 32;

const animation_item = struct {
    id: u64,
    progress: f64,
    time: f64,
    initial: f64,
    prev: f64,
};

var animations: [ANIMATION_MAX_ITEMS]animation_item = undefined;
var animation_item_count: usize = 0;

pub fn ease_out_elastic(x: f64) f64 {
    const c4 = (2.0 * std.math.pi) / 3.0;

    if (x == 0) {
        return 0;
    } else if (x == 1) {
        return 1.0;
    } else {
        return std.math.pow(f64, 2, -10.0 * x) * std.math.sin((x * 10.0 - 0.75) * c4) + 1.0;
    }
}

pub fn animation_update_all(dt: f64) void {
    if (animation_item_count == 0) {
        return;
    }
    var it: i64 = @as(i64, @intCast(animation_item_count)) - 1;
    while (it >= 0) {
        var item: *animation_item = &animations[@intCast(it)];
        item.progress += (dt / item.time);
        if (item.progress >= 1.0) {
            animation_item_count -= 1;
            item.* = animations[animation_item_count];
        }
        it -= 1;
    }
}

pub fn animation_start(id: u64, initial: f64, time: f64) void {
    for (0..animation_item_count) |it| {
        var item: *animation_item = &animations[it];
        if (item.id == id) {
            item.initial = 0; //item.prev;

            item.time = time;
            item.progress = 0;
            return;
        }
    }

    if (animation_item_count < ANIMATION_MAX_ITEMS) {
        animations[animation_item_count] = animation_item{ .id = id, .initial = initial, .prev = initial, .time = time, .progress = 0 };
        animation_item_count += 1;
    }
}

pub fn animation_get(id: u64, target: f64) f64 {
    for (0..animation_item_count) |it| {
        var item: *animation_item = &animations[it];
        if (item.id == id) {
            var p: f64 = item.progress;
            //p = 1 - (1 - p) * (1 - p);
            p = ease_out_elastic(p);
            item.prev = item.initial + p * (target - item.initial);
            return item.prev;
        }
    }
    return target;
}
