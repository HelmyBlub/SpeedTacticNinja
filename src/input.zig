const std = @import("std");
const main = @import("main.zig");
const windowSdlZig = @import("windowSdl.zig");
const sdl = windowSdlZig.sdl;
const movePieceZig = @import("movePiece.zig");
const shopZig = @import("shop.zig");
const playerZig = @import("player.zig");
const modeSelectZig = @import("modeSelect.zig");
const autoTestZig = @import("autoTest.zig");
const settingsMenuVulkanZig = @import("vulkan/settingsMenuVulkan.zig");

pub const PlayerInputData = struct {
    inputDevice: ?InputDeviceData = null,
    lastInputDevice: ?InputDeviceData = null,
    holdingKeySinceForLeave: ?i64 = null,
    axis0DeadZone: bool = true,
    axis1DeadZone: bool = true,
    axis0Id: u8 = 0,
    axis1Id: u8 = 0,
    lastInputTime: i64 = 0,
};

pub const InputJoinData = struct {
    inputDeviceDatas: std.ArrayList(InputJoinDeviceData),
    disconnectedGamepads: std.ArrayList(u32),
};

pub const InputJoinDeviceData = struct {
    deviceData: InputDeviceData,
    pressTime: i64,
};

pub const InputDevice = enum {
    keyboard,
    gamepad,
};

pub const InputDeviceData = union(InputDevice) {
    keyboard: ?u32,
    gamepad: u32,
};

pub const PlayerAction = enum {
    pieceSelect1,
    pieceSelect2,
    pieceSelect3,
    moveUp,
    moveDown,
    moveLeft,
    moveRight,
    pauseGame,
};

const KeyboardKeyBind = struct {
    action: PlayerAction,
    sdlKeyCode: c_int,
};

const GamepadActionBind = struct {
    action: PlayerAction,
    buttonId: u8,
};

pub const ButtonDisplay = struct {
    text: []const u8,
    device: InputDevice,
};

const GAMEPAD_XBOX_MAPPING = [_]GamepadActionBind{
    .{ .action = .moveDown, .buttonId = 12 },
    .{ .action = .moveUp, .buttonId = 11 },
    .{ .action = .moveLeft, .buttonId = 13 },
    .{ .action = .moveRight, .buttonId = 14 },
    .{ .action = .pieceSelect1, .buttonId = 0 },
    .{ .action = .pieceSelect2, .buttonId = 1 },
    .{ .action = .pieceSelect3, .buttonId = 2 },
    .{ .action = .pauseGame, .buttonId = 6 },
};

const KEYBOARD_MAPPING_1 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_S },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_W },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_A },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_D },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_1 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_2 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_3 },
    .{ .action = .pauseGame, .sdlKeyCode = sdl.SDL_SCANCODE_ESCAPE },
};
const KEYBOARD_MAPPING_2 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_DOWN },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_UP },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_LEFT },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_RIGHT },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_KP_1 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_KP_2 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_KP_3 },
};
const KEYBOARD_MAPPING_3 = [_]KeyboardKeyBind{
    .{ .action = .moveDown, .sdlKeyCode = sdl.SDL_SCANCODE_K },
    .{ .action = .moveUp, .sdlKeyCode = sdl.SDL_SCANCODE_I },
    .{ .action = .moveLeft, .sdlKeyCode = sdl.SDL_SCANCODE_J },
    .{ .action = .moveRight, .sdlKeyCode = sdl.SDL_SCANCODE_L },
    .{ .action = .pieceSelect1, .sdlKeyCode = sdl.SDL_SCANCODE_7 },
    .{ .action = .pieceSelect2, .sdlKeyCode = sdl.SDL_SCANCODE_8 },
    .{ .action = .pieceSelect3, .sdlKeyCode = sdl.SDL_SCANCODE_9 },
};
pub const KEYBOARD_MAPPINGS = [_][]const KeyboardKeyBind{
    &KEYBOARD_MAPPING_1,
    &KEYBOARD_MAPPING_2,
    &KEYBOARD_MAPPING_3,
};

pub fn handlePlayerInput(event: sdl.SDL_Event, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.inputData.inputDevice) |device| {
            switch (device) {
                .gamepad => |gamepadId| {
                    try handlePlayerGamepadInput(event, player, gamepadId, state);
                },
                .keyboard => |mappingIndex| {
                    try handlePlayerKeyboardInput(event, player, mappingIndex, state);
                },
            }
        } else {
            try handlePlayerGamepadInput(event, player, null, state);
            try handlePlayerKeyboardInput(event, player, null, state);
        }
    }
    try handleCheckPlayerJoin(event, state);
}

pub fn getPlayerInputDevice(player: *playerZig.Player) ?InputDeviceData {
    var inputDevice: ?InputDeviceData = null;
    if (player.inputData.inputDevice == null) {
        if (player.inputData.lastInputDevice == null or player.inputData.lastInputDevice.? == .keyboard) {
            inputDevice = .{ .keyboard = 0 };
        } else {
            inputDevice = player.inputData.lastInputDevice;
        }
    } else {
        inputDevice = player.inputData.inputDevice;
        if (inputDevice.? == .keyboard and inputDevice.?.keyboard == null) {
            inputDevice = .{ .keyboard = 0 };
        }
    }
    return inputDevice;
}

pub fn getDisplayInfoForPlayerAction(player: *playerZig.Player, action: PlayerAction, state: *main.GameState) ?ButtonDisplay {
    const inputDevice = getPlayerInputDevice(player);
    if (inputDevice == null) return null;
    switch (inputDevice.?) {
        .keyboard => |index| {
            const mappings = KEYBOARD_MAPPINGS[index.?];
            for (mappings) |mapping| {
                if (mapping.action == action) {
                    const text = getDisplayTextForScancode(@intCast(mapping.sdlKeyCode), state);
                    return ButtonDisplay{ .text = text, .device = .keyboard };
                }
            }
            return null;
        },
        .gamepad => |_| {
            switch (action) {
                .pieceSelect1 => {
                    return ButtonDisplay{ .text = "A", .device = .gamepad };
                },
                .pieceSelect2 => {
                    return ButtonDisplay{ .text = "B", .device = .gamepad };
                },
                .pieceSelect3 => {
                    return ButtonDisplay{ .text = "X", .device = .gamepad };
                },
                else => {
                    return null;
                },
            }
        },
    }
}

pub fn onPlayerMoveActionFinished(player: *playerZig.Player, state: *main.GameState) !void {
    if (state.gamePhase == .shopping) {
        try shopZig.executeShopActionForPlayer(player, state);
    } else if (state.gamePhase == .modeSelect) {
        try modeSelectZig.onPlayerMoveActionFinished(player, state);
    }
}

fn getDisplayTextForScancode(scancode: c_uint, state: *main.GameState) []const u8 {
    const cString = sdl.SDL_GetScancodeName(scancode);
    const zigString: []const u8 = std.mem.span(cString);
    if (zigString.len > 1) {
        if (std.mem.startsWith(u8, zigString, "Keypad")) {
            state.tempStringBuffer[0] = 'K';
            state.tempStringBuffer[1] = zigString[zigString.len - 1];
            return state.tempStringBuffer[0..2];
        } else {
            return zigString;
        }
    } else {
        return zigString;
    }
}

fn handleCheckPlayerJoin(event: sdl.SDL_Event, state: *main.GameState) !void {
    if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
        const mappingIndex = getKeyboardMappingIndex(event);
        if (mappingIndex == null) return;
        for (state.players.items) |*player| {
            if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .keyboard and player.inputData.inputDevice.?.keyboard == mappingIndex) return;
        }
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.deviceData == .keyboard and joinData.deviceData.keyboard == mappingIndex) return;
        }
        try state.inputJoinData.inputDeviceDatas.append(.{ .pressTime = std.time.milliTimestamp(), .deviceData = .{ .keyboard = mappingIndex } });
    }
    if (event.type == sdl.SDL_EVENT_KEY_UP) {
        const mappingIndex = getKeyboardMappingIndex(event);
        if (mappingIndex == null) return;
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.deviceData == .keyboard and joinData.deviceData.keyboard == mappingIndex) {
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                return;
            }
        }
    }

    if (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN) {
        for (state.players.items) |*player| {
            if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .gamepad and player.inputData.inputDevice.?.gamepad == event.gdevice.which) {
                return;
            }
        }
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.deviceData == .gamepad and joinData.deviceData.gamepad == event.gdevice.which) return;
        }
        try state.inputJoinData.inputDeviceDatas.append(.{ .pressTime = std.time.milliTimestamp(), .deviceData = .{ .gamepad = event.gdevice.which } });
    }
    if (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_UP) {
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.deviceData == .gamepad and joinData.deviceData.gamepad == event.gdevice.which) {
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                return;
            }
        }
    }
}

fn getKeyboardMappingIndex(event: sdl.SDL_Event) ?u32 {
    for (KEYBOARD_MAPPINGS, 0..) |keyMappings, index| {
        for (keyMappings) |mapping| {
            if (mapping.sdlKeyCode == event.key.scancode) return @intCast(index);
        }
    }
    return null;
}

fn handlePlayerKeyboardInput(event: sdl.SDL_Event, player: *playerZig.Player, keyboardMappingIndex: ?u32, state: *main.GameState) !void {
    if (event.type != sdl.SDL_EVENT_KEY_DOWN and event.type != sdl.SDL_EVENT_KEY_UP) return;

    if (keyboardMappingIndex) |index| {
        const keyMapping = KEYBOARD_MAPPINGS[index];
        for (keyMapping) |mapping| {
            if (mapping.sdlKeyCode == event.key.scancode) {
                if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
                    if (player.inputData.holdingKeySinceForLeave == null) player.inputData.holdingKeySinceForLeave = std.time.milliTimestamp();
                    try handlePlayerAction(mapping.action, player, state);
                } else {
                    player.inputData.holdingKeySinceForLeave = null;
                    if (state.gameOver or state.paused) {
                        if (mapping.action == .pieceSelect1) state.uxData.continueButtonHoldStart = null;
                        if (mapping.action == .pieceSelect2) state.uxData.restartButtonHoldStart = null;
                        if (mapping.action == .pieceSelect3) state.uxData.quitButtonHoldStart = null;
                    }
                }
            }
        }
    } else {
        for (KEYBOARD_MAPPINGS, 0..) |keyMappings, index| {
            for (keyMappings) |mapping| {
                if (mapping.sdlKeyCode == event.key.scancode) {
                    player.inputData.lastInputDevice = .{ .keyboard = @intCast(index) };
                    if (event.type == sdl.SDL_EVENT_KEY_DOWN) {
                        try handlePlayerAction(mapping.action, player, state);
                    } else {
                        if (state.gameOver or state.paused) {
                            if (mapping.action == .pieceSelect1) state.uxData.continueButtonHoldStart = null;
                            if (mapping.action == .pieceSelect2) state.uxData.restartButtonHoldStart = null;
                            if (mapping.action == .pieceSelect3) state.uxData.quitButtonHoldStart = null;
                        }
                    }
                }
            }
        }
    }
}

fn handlePlayerGamepadInput(event: sdl.SDL_Event, player: *playerZig.Player, gamepadId: ?u32, state: *main.GameState) !void {
    if (gamepadId != null and event.gdevice.which != gamepadId) return;
    try settingsMenuVulkanZig.handleGamepadSettingsMenuInput(event, player, state);

    const deadzoneLimit = 15000;
    switch (event.type) {
        sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION => {
            const isInDeadZone = player.inputData.axis0DeadZone and player.inputData.axis1DeadZone;
            if (@mod(event.gaxis.axis, 2) == 1) {
                if (event.gaxis.value > deadzoneLimit) {
                    if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
                    if (isInDeadZone) {
                        try handlePlayerAction(.moveDown, player, state);
                    }
                    player.inputData.axis1Id = event.gaxis.axis;
                    player.inputData.axis1DeadZone = false;
                } else if (event.gaxis.value < -deadzoneLimit) {
                    if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
                    if (isInDeadZone) {
                        try handlePlayerAction(.moveUp, player, state);
                    }
                    player.inputData.axis1Id = event.gaxis.axis;
                    player.inputData.axis1DeadZone = false;
                } else if (player.inputData.axis1Id == event.gaxis.axis) {
                    player.inputData.axis1DeadZone = true;
                }
            } else {
                if (event.gaxis.value > deadzoneLimit) {
                    if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
                    if (isInDeadZone) {
                        try handlePlayerAction(.moveRight, player, state);
                    }
                    player.inputData.axis0Id = event.gaxis.axis;
                    player.inputData.axis0DeadZone = false;
                } else if (event.gaxis.value < -deadzoneLimit) {
                    if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
                    if (isInDeadZone) {
                        try handlePlayerAction(.moveLeft, player, state);
                    }
                    player.inputData.axis0Id = event.gaxis.axis;
                    player.inputData.axis0DeadZone = false;
                } else if (player.inputData.axis0Id == event.gaxis.axis) {
                    player.inputData.axis0DeadZone = true;
                }
            }
        },
        sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN => {
            if (gamepadId == null) player.inputData.lastInputDevice = .{ .gamepad = event.gdevice.which };
            for (GAMEPAD_XBOX_MAPPING) |mapping| {
                if (mapping.buttonId == event.gbutton.button) {
                    try handlePlayerAction(mapping.action, player, state);
                    if (mapping.action == .pauseGame) {
                        if ((!state.paused or !state.gameOver) and state.uxData.settingsMenuUx.menuOpen) {
                            state.uxData.settingsMenuUx.gamePadSelectIndex = null;
                            state.uxData.settingsMenuUx.menuOpen = false;
                        }
                        break;
                    }
                }
            }
            if (gamepadId != null) {
                player.inputData.holdingKeySinceForLeave = std.time.milliTimestamp();
            }
        },
        sdl.SDL_EVENT_GAMEPAD_BUTTON_UP => {
            player.inputData.holdingKeySinceForLeave = null;
            if (state.gameOver or state.paused) {
                for (GAMEPAD_XBOX_MAPPING) |mapping| {
                    if (mapping.buttonId == event.gbutton.button) {
                        if (mapping.action == .pieceSelect1) {
                            state.uxData.continueButtonHoldStart = null;
                            break;
                        }
                        if (mapping.action == .pieceSelect2) {
                            state.uxData.restartButtonHoldStart = null;
                            break;
                        }
                        if (mapping.action == .pieceSelect3) {
                            state.uxData.quitButtonHoldStart = null;
                            break;
                        }
                    }
                }
            }
        },
        else => {},
    }
}

pub fn handlePlayerAction(action: PlayerAction, player: *playerZig.Player, state: *main.GameState) !void {
    try autoTestZig.recordPlayerInput(action, player, state);
    player.inputData.lastInputTime = state.gameTime;
    if (state.gameOver and state.timeFreezed != null and state.timeFreezed.? >= 1500) state.timeFreezed = null;
    switch (action) {
        .moveLeft => {
            if (!state.paused and !state.gameOver) {
                if (player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_LEFT, state);
                } else if (state.gamePhase == .shopping or state.gamePhase == .modeSelect) {
                    player.position.x -= main.TILESIZE;
                    try onPlayerMoveActionFinished(player, state);
                }
            }
        },
        .moveRight => {
            if (!state.paused and !state.gameOver) {
                if (player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_RIGHT, state);
                } else if (state.gamePhase == .shopping or state.gamePhase == .modeSelect) {
                    player.position.x += main.TILESIZE;
                    try onPlayerMoveActionFinished(player, state);
                }
            }
        },
        .moveUp => {
            if (!state.paused and !state.gameOver) {
                if (player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_UP, state);
                } else if (state.gamePhase == .shopping or state.gamePhase == .modeSelect) {
                    player.position.y -= main.TILESIZE;
                    try onPlayerMoveActionFinished(player, state);
                }
            }
        },
        .moveDown => {
            if (!state.paused and !state.gameOver) {
                if (player.choosenMoveOptionIndex) |index| {
                    try movePieceZig.movePlayerByMovePiece(player, index, movePieceZig.DIRECTION_DOWN, state);
                } else if (state.gamePhase == .shopping or state.gamePhase == .modeSelect) {
                    player.position.y += main.TILESIZE;
                    try onPlayerMoveActionFinished(player, state);
                }
            }
        },
        .pieceSelect1 => {
            if (state.paused or state.gameOver) {
                if (state.uxData.continueButtonHoldStart == null) state.uxData.continueButtonHoldStart = std.time.milliTimestamp();
            } else {
                movePieceZig.setMoveOptionIndex(player, 0, state);
            }
        },
        .pieceSelect2 => {
            if (state.paused or state.gameOver) {
                if (state.uxData.restartButtonHoldStart == null) state.uxData.restartButtonHoldStart = std.time.milliTimestamp();
            } else {
                movePieceZig.setMoveOptionIndex(player, 1, state);
            }
        },
        .pieceSelect3 => {
            if (state.paused or state.gameOver) {
                if (state.uxData.quitButtonHoldStart == null) state.uxData.quitButtonHoldStart = std.time.milliTimestamp();
            } else {
                movePieceZig.setMoveOptionIndex(player, 2, state);
            }
        },
        .pauseGame => {
            if (state.paused) {
                state.paused = false;
                state.pauseInputTime = null;
            } else if (!state.gameOver) {
                if (state.pauseInputTime == null) state.pauseInputTime = state.gameTime;
            }
        },
    }
}
