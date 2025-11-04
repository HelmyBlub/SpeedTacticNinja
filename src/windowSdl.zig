const std = @import("std");
const buildin = @import("builtin");
pub const sdl = @cImport({
    @cDefine("VK_NO_PROTOTYPES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    @cInclude("SDL3/SDL_vulkan.h");
});
const main = @import("main.zig");
const shopZig = @import("shop.zig");
const inputZig = @import("input.zig");
const equipmentZig = @import("equipment.zig");
const settingsMenuVulkanZig = @import("vulkan/settingsMenuVulkan.zig");
const achievementZig = @import("achievement.zig");
const autoTestZig = @import("autoTest.zig");
const modeSelectZig = @import("modeSelect.zig");
const movePieceZig = @import("movePiece.zig");

pub const WindowData = struct {
    window: ?*sdl.SDL_Window = null,
    widthFloat: f32 = 1600,
    heightFloat: f32 = 800,
    onePixelXInVulkan: f32 = 2.0 / 1600.0,
    onePixelYInVulkan: f32 = 2.0 / 800.0,
};

pub fn initWindowSdl(state: *main.GameState) !void {
    _ = sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO | sdl.SDL_INIT_GAMEPAD);
    const flags = sdl.SDL_WINDOW_VULKAN | sdl.SDL_WINDOW_RESIZABLE;
    state.windowData.window = try (sdl.SDL_CreateWindow("Speed Tactic Ninja", @intFromFloat(state.windowData.widthFloat), @intFromFloat(state.windowData.heightFloat), flags) orelse error.createWindow);
    _ = sdl.SDL_ShowWindow(state.windowData.window.?);
}

pub fn destroyWindowSdl(state: *main.GameState) void {
    if (state.windowData.window) |window| sdl.SDL_DestroyWindow(window);
    sdl.SDL_Quit();
}

pub fn getSurfaceForVulkan(instance: sdl.VkInstance, state: *main.GameState) sdl.VkSurfaceKHR {
    var surface: sdl.VkSurfaceKHR = undefined;
    _ = sdl.SDL_Vulkan_CreateSurface(state.windowData.window.?, instance, null, &surface);
    return surface;
}

pub fn getWindowSize(width: *u32, height: *u32, state: *main.GameState) void {
    var w: c_int = undefined;
    var h: c_int = undefined;
    _ = sdl.SDL_GetWindowSize(state.windowData.window.?, &w, &h);
    width.* = @intCast(w);
    height.* = @intCast(h);
}

pub fn setFullscreen(fullscreen: bool, state: *main.GameState) void {
    const window = state.windowData.window.?;
    const flags = sdl.SDL_GetWindowFlags(window);
    if (fullscreen and (flags & sdl.SDL_WINDOW_FULLSCREEN) == 0) {
        _ = sdl.SDL_SetWindowFullscreen(window, true);
    } else if (!fullscreen and (flags & sdl.SDL_WINDOW_FULLSCREEN) != 0) {
        _ = sdl.SDL_SetWindowFullscreen(window, false);
    }
}

pub fn handleEvents(state: *main.GameState) !void {
    var event: sdl.SDL_Event = undefined;
    const timeStamp = std.time.milliTimestamp();
    while (sdl.SDL_PollEvent(&event)) {
        if (event.type == sdl.SDL_EVENT_QUIT) {
            std.debug.print("clicked window X \n", .{});
            state.gameQuit = true;
            return;
        }
        if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
            if (state.tutorialData.active and state.tutorialData.firstKeyDownInput == null) {
                state.tutorialData.firstKeyDownInput = timeStamp;
            }
            if (buildin.mode == .Debug) try debugKeys(event, state);
            if (state.modeSelect.selectedMode == .practice) try modeSelectZig.handlePracticeModeKeys(event, state);
        }
        try handleGamePadEvents(event, state);
        try inputZig.handlePlayerInput(event, state);
        if (event.type == sdl.SDL_EVENT_MOUSE_MOTION) {
            state.uxData.lastMouseInput = timeStamp;
            state.vulkanMousePosition = mouseWindowPositionToVulkanSurfacePoisition(event.motion.x, event.motion.y, state);
            try settingsMenuVulkanZig.mouseMove(state);
        }
        if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_DOWN) {
            state.uxData.lastMouseInput = timeStamp;
            state.vulkanMousePosition = mouseWindowPositionToVulkanSurfacePoisition(event.motion.x, event.motion.y, state);
            try settingsMenuVulkanZig.mouseDown(state);
        }
        if (event.type == sdl.SDL_EVENT_MOUSE_BUTTON_UP) {
            state.uxData.lastMouseInput = timeStamp;
            state.vulkanMousePosition = mouseWindowPositionToVulkanSurfacePoisition(event.motion.x, event.motion.y, state);
            try settingsMenuVulkanZig.mouseUp(state);
        }
    }
    if (timeStamp > state.uxData.lastMouseInput + 5_000) {
        if (sdl.SDL_CursorVisible()) {
            _ = sdl.SDL_HideCursor();
            state.vulkanMousePosition = null;
        }
    } else if (!sdl.SDL_CursorVisible()) {
        _ = sdl.SDL_ShowCursor();
    }
}

fn handleGamePadEvents(event: sdl.SDL_Event, state: *main.GameState) !void {
    switch (event.type) {
        sdl.SDL_EVENT_GAMEPAD_ADDED => {
            std.debug.print("event: Gamepad added\n", .{});
            const which: sdl.SDL_JoystickID = event.gdevice.which;
            const gamepad: ?*sdl.SDL_Gamepad = sdl.SDL_OpenGamepad(which);
            if (gamepad == null) {
                std.debug.print("gamepad open failed: {s}\n", .{sdl.SDL_GetError()});
            } else {
                if (state.inputJoinData.disconnectedGamepads.items.len > 0) {
                    const replace = state.inputJoinData.disconnectedGamepads.orderedRemove(0);
                    for (state.players.items) |*player| {
                        if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .gamepad and player.inputData.inputDevice.?.gamepad == replace) {
                            player.inputData.inputDevice.?.gamepad = which;
                            break;
                        }
                    }
                }
            }
        },
        sdl.SDL_EVENT_GAMEPAD_REMOVED => {
            std.debug.print("event: Gamepad removed\n", .{});
            const which: sdl.SDL_JoystickID = event.gdevice.which;
            const gamepad: ?*sdl.SDL_Gamepad = sdl.SDL_GetGamepadFromID(which);
            for (state.players.items) |*player| {
                if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .gamepad and player.inputData.inputDevice.?.gamepad == which) {
                    if (state.gamePhase == .combat or state.gamePhase == .boss) {
                        try autoTestZig.recordPlayerInput(.pauseGame, player, state);
                        state.pauseInputTime = state.gameTime;
                    }
                    try state.inputJoinData.disconnectedGamepads.append(which);
                    break;
                } else if (player.inputData.lastInputDevice != null and player.inputData.lastInputDevice.? == .gamepad and player.inputData.lastInputDevice.?.gamepad == which) {
                    if (state.gamePhase == .combat or state.gamePhase == .boss) {
                        try autoTestZig.recordPlayerInput(.pauseGame, &state.players.items[0], state);
                        state.pauseInputTime = state.gameTime;
                    }
                }
            }
            if (gamepad != null) {
                sdl.SDL_CloseGamepad(gamepad);
            }
        },
        else => {},
    }
}

fn debugKeys(event: sdl.SDL_Event, state: *main.GameState) !void {
    if (event.key.scancode == sdl.SDL_SCANCODE_F5) {
        state.statistics.active = false;
        achievementZig.stopTrackingAchievmentForThisRun(state);
        try state.uxData.achievementGained.append(.{ .imageIndex = 0, .name = "test", .displayStartTime = state.gameTime });
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F6) {
        state.statistics.active = false;
        achievementZig.stopTrackingAchievmentForThisRun(state);
        state.continueData.freeContinues += 1;
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F7) {
        const randomPiece = try movePieceZig.createRandomMovePieceStepsLength(state.allocator, 1, 3, state);
        try movePieceZig.addMovePiece(&state.players.items[0], randomPiece);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F8) {
        state.statistics.active = false;
        achievementZig.stopTrackingAchievmentForThisRun(state);
        _ = equipmentZig.equip(equipmentZig.getEquipmentOptionByIndexScaledToLevel(7, state.level).equipment, true, &state.players.items[0]);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F9) {
        state.statistics.active = false;
        achievementZig.stopTrackingAchievmentForThisRun(state);
        for (state.players.items) |*player| {
            player.money += 200;
        }
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F11) {
        try autoTestZig.replayRecording(state);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F12) {
        try autoTestZig.saveRecordingToFile(state);
    }
}

pub fn mouseWindowPositionToGameMapPoisition(x: f32, y: f32, camera: main.Camera, state: *main.GameState) main.Position {
    var width: u32 = 0;
    var height: u32 = 0;
    getWindowSize(&width, &height, state);
    const widthFloatWindow = @as(f64, @floatFromInt(width));
    const heightFloatWindow = @as(f64, @floatFromInt(height));

    const scaleToPixelX = state.windowData.widthFloat / widthFloatWindow;
    const scaleToPixelY = state.windowData.heightFloat / heightFloatWindow;

    return main.Position{
        .x = (x - widthFloatWindow / 2) * scaleToPixelX / camera.zoom + camera.position.x,
        .y = (y - heightFloatWindow / 2) * scaleToPixelY / camera.zoom + camera.position.y,
    };
}

pub fn mouseWindowPositionToVulkanSurfacePoisition(x: f32, y: f32, state: *main.GameState) main.Position {
    var width: u32 = 0;
    var height: u32 = 0;
    getWindowSize(&width, &height, state);
    const widthFloat = @as(f32, @floatFromInt(width));
    const heightFloat = @as(f32, @floatFromInt(height));

    return main.Position{
        .x = x / widthFloat * 2 - 1,
        .y = y / heightFloat * 2 - 1,
    };
}
