const std = @import("std");
const main = @import("main.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const shopZig = @import("shop.zig");
const equipmentZig = @import("equipment.zig");
const inputZig = @import("input.zig");
const soundMixerZig = @import("soundMixer.zig");
const windowSdlZig = @import("windowSdl.zig");
const autoTestZig = @import("autoTest.zig");
const modeSelectZig = @import("modeSelect.zig");

pub const Player = struct {
    position: main.Position = .{ .x = 0, .y = 0 },
    phase: PlayePhase = .combat,
    damage: u32 = 0,
    damagePerCentFactor: f32 = 1,
    immunUntilTime: i64 = 0,
    executeMovePiece: ?movePieceZig.MovePiece = null,
    executeDirection: u8 = 0,
    afterImages: std.ArrayList(AfterImage),
    choosenMoveOptionIndex: ?usize = null,
    choosenMoveOptionVisualizationOverlapping: bool = false,
    moveOptions: std.ArrayList(movePieceZig.MovePiece),
    totalMovePieces: std.ArrayList(movePieceZig.MovePiece),
    availableMovePieces: std.ArrayList(movePieceZig.MovePiece),
    paintData: ninjaDogVulkanZig.NinjaDogPaintData = .{},
    animateData: ninjaDogVulkanZig.NinjaDogAnimationStateData = .{},
    slashedLastMoveTile: bool = false,
    money: u32 = 0,
    moneyOnShopLeftForSave: u32 = 0,
    isDead: bool = false,
    shop: shopZig.ShopPlayerData = .{},
    inAirHeight: f32 = 0,
    fallVelocity: f32 = 0,
    startedFallingState: ?i64 = null,
    fallingStateDamageDelay: i32 = 1500,
    equipment: equipmentZig.EquipmentData = .{},
    moneyBonusPerCent: f32 = 0,
    lastMoveDirection: ?u8 = null,
    uxData: PlayerUxData = .{},
    inputData: inputZig.PlayerInputData = .{},
    modeData: modeSelectZig.ModePlayerData = .none,
};

const PlayePhase = enum {
    combat,
    shopping,
};

const PlayerUxData = struct {
    vulkanTopLeft: main.Position = .{ .x = 0, .y = 0 },
    vulkanScale: f32 = 0.4,
    piecesRefreshedVisualization: ?i64 = null,
    visualizeMovePieceChangeFromShop: ?i32 = null,
    visualizationDuration: i32 = 1500,
    visualizeMoney: ?i32 = null,
    visualizeMoneyUntil: ?i64 = null,
    visualizeHpChange: ?i32 = null,
    visualizeHpChangeUntil: ?i64 = null,
    visualizeChoiceKeys: bool = true,
    visualizeMovementKeys: bool = true,
    visualizeChoosenMovePieceColor: [4]f32 = .{ 0, 0, 0, 1 },
    infoRecMovePieces: main.Rectangle = .{},
    infoRecMovePieceCount: main.Rectangle = .{},
    infoRecDamage: main.Rectangle = .{},
    infoRecHealth: main.Rectangle = .{},
    infoRecMoney: main.Rectangle = .{},
};

pub const AfterImage = struct {
    paintData: ninjaDogVulkanZig.NinjaDogPaintData,
    position: main.Position,
    deleteTime: i64,
};

pub const PLAYER_JOIN_BUTTON_HOLD_DURATION = 4000;

pub fn tickPlayers(state: *main.GameState, passedTime: i64) !void {
    for (state.players.items) |*player| {
        if (player.isDead) continue;
        if (player.inAirHeight > 0) {
            const fPassedTime = @as(f32, @floatFromInt(passedTime));
            player.fallVelocity = @min(5, player.fallVelocity + fPassedTime * 0.001);
            player.inAirHeight -= player.fallVelocity * fPassedTime;
            if (player.inAirHeight < 0) {
                player.fallVelocity = 0;
                player.inAirHeight = 0;
            }
        } else {
            try movePieceZig.tickPlayerMovePiece(player, state);
        }
        if (player.startedFallingState) |time| {
            if (state.mapData.mapType == .top) {
                if (time + player.fallingStateDamageDelay <= state.gameTime) {
                    try playerHit(player, state);
                }
            } else {
                player.startedFallingState = null;
            }
        }
        try ninjaDogVulkanZig.tickNinjaDogAnimation(player, passedTime, state);
    }
    const timestamp = std.time.milliTimestamp();
    if (state.gamePhase != .boss) {
        for (state.inputJoinData.inputDeviceDatas.items, 0..) |joinData, index| {
            if (joinData.pressTime + PLAYER_JOIN_BUTTON_HOLD_DURATION <= timestamp) {
                try playerJoin(.{ .inputDevice = joinData.deviceData }, state);
                _ = state.inputJoinData.inputDeviceDatas.swapRemove(index);
                break;
            }
        }
        for (state.players.items, 0..) |*player, index| {
            if (player.inputData.holdingKeySinceForLeave) |startTime| {
                if (startTime + PLAYER_JOIN_BUTTON_HOLD_DURATION <= timestamp) {
                    try playerLeave(index, state);
                    break;
                }
            }
        }
    }
}

pub fn createPlayer(allocator: std.mem.Allocator) Player {
    return .{
        .moveOptions = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .availableMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .totalMovePieces = std.ArrayList(movePieceZig.MovePiece).init(allocator),
        .afterImages = std.ArrayList(AfterImage).init(allocator),
    };
}

pub fn destroyPlayer(player: *Player, state: *main.GameState) void {
    player.moveOptions.deinit();
    player.availableMovePieces.deinit();
    if (player.totalMovePieces.items.len > 0) {
        for (player.totalMovePieces.items) |movePiece| {
            state.allocator.free(movePiece.steps);
        }
    }
    player.totalMovePieces.deinit();
    player.afterImages.deinit();
    for (player.shop.piecesToBuy) |optPiece| {
        if (optPiece) |piece| {
            state.allocator.free(piece.steps);
        }
    }
}

pub fn movePlayerToLevelSpawnPosition(state: *main.GameState) void {
    const playerSpawnOffsets = [_]main.Position{
        .{ .x = -1, .y = -1 },
        .{ .x = 1, .y = 1 },
        .{ .x = 1, .y = -1 },
        .{ .x = -1, .y = 1 },
        .{ .x = 0, .y = -1 },
        .{ .x = 0, .y = 1 },
        .{ .x = 1, .y = 0 },
        .{ .x = -1, .y = 0 },
    };
    const mapRadiusWidth: f32 = @as(f32, @floatFromInt(state.mapData.tileRadiusWidth)) * main.TILESIZE;
    const mapRadiusHeight: f32 = @as(f32, @floatFromInt(state.mapData.tileRadiusHeight)) * main.TILESIZE;
    for (state.players.items, 0..) |*player, index| {
        player.position.x = playerSpawnOffsets[@mod(index, playerSpawnOffsets.len)].x * mapRadiusWidth;
        player.position.y = playerSpawnOffsets[@mod(index, playerSpawnOffsets.len)].y * mapRadiusHeight;
    }
}

pub fn findClosestPlayer(position: main.Position, state: *main.GameState) *Player {
    var shortestDistance: f32 = 0;
    var closestPlayer: ?*Player = null;
    for (state.players.items) |*player| {
        const tempDistance = main.calculateDistance(position, player.position);
        if (closestPlayer == null or tempDistance < shortestDistance) {
            shortestDistance = tempDistance;
            closestPlayer = player;
        }
    }
    return closestPlayer.?;
}

pub fn changePlayerMoneyBy(amount: i32, player: *Player, visualize: bool, state: *main.GameState) !void {
    player.money = @intCast(@as(i32, @intCast(player.money)) + amount);
    if (visualize and amount != 0) {
        if (player.uxData.visualizeMoney != null) {
            player.uxData.visualizeMoney.? += amount;
        } else {
            player.uxData.visualizeMoney = amount;
        }
        player.uxData.visualizeMoneyUntil = null;
    }
    if (amount < 0) {
        try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_PAY_MONEY, 0, 1);
        state.achievements.getPtr(.beatBoss5WithoutSpendingMoney).trackingActive = false;
    }
}

pub fn playerHit(player: *Player, state: *main.GameState) !void {
    if (player.immunUntilTime >= state.gameTime) return;
    if (player.isDead) return;
    if (player.phase == .shopping and state.gamePhase == .combat) return;
    if (state.players.items.len == 1 and state.timeFreezeOnHit) {
        state.timeFreezed = 0;
    }
    state.achievements.getPtr(.beatGameWithoutTakingDamage).trackingActive = false;
    if (!try equipmentZig.damageTakenByEquipment(player, state)) {
        player.isDead = true;
        state.gameOver = main.isGameOver(state);
        if (state.gameOver) {
            state.gameOverRealTime = std.time.milliTimestamp();
        }
        try ninjaDogDeathCutSprites(player, state);
    } else {
        try movePieceZig.resetPieces(player, true, state);
    }

    if (player.uxData.visualizeHpChange != null) {
        player.uxData.visualizeHpChange.? -= 1;
    } else {
        player.uxData.visualizeHpChange = -1;
    }
    player.uxData.visualizeHpChangeUntil = state.gameTime + player.uxData.visualizationDuration;

    player.immunUntilTime = state.gameTime + state.config.playerImmunityFrames;
    state.playerTookDamageOnLevel = true;
    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_PLAYER_HIT, 0, 1);
}

pub fn resetPlayer(player: *Player, state: *main.GameState) !void {
    player.money = 0;
    player.moneyOnShopLeftForSave = 0;
    player.phase = .combat;
    player.isDead = false;
    player.position.x = 0;
    player.position.y = 0;
    player.afterImages.clearRetainingCapacity();
    player.animateData = .{};
    player.paintData = .{};
    player.executeMovePiece = null;
    player.shop.gridDisplayPiece = null;
    player.shop.selectedOption = .none;
    player.immunUntilTime = 0;
    player.choosenMoveOptionIndex = null;
    player.lastMoveDirection = null;
    equipmentZig.equipStarterEquipment(player);
    try movePieceZig.setupMovePieces(player, state);
    player.uxData.visualizeHpChangeUntil = null;
    player.uxData.visualizeMoneyUntil = null;
    player.uxData.visualizeMovePieceChangeFromShop = null;
    player.uxData.piecesRefreshedVisualization = null;
    player.uxData.visualizeHpChange = null;
    player.uxData.visualizeMoney = null;
    player.inputData.lastInputTime = 0;
    player.slashedLastMoveTile = false;
}

pub fn getRandomAlivePlayerIndex(state: *main.GameState) ?usize {
    var alivePlayerCount: usize = 0;
    for (state.players.items) |player| {
        if (!player.isDead) alivePlayerCount += 1;
    }
    if (alivePlayerCount == 0) return null;
    const randomCount = state.seededRandom.random().intRangeLessThan(usize, 0, alivePlayerCount);
    alivePlayerCount = 0;
    for (state.players.items, 0..) |player, index| {
        if (player.isDead) continue;
        if (alivePlayerCount == randomCount) return index;
        if (!player.isDead) alivePlayerCount += 1;
    }
    return 0;
}

pub fn getClosestPlayer(position: main.Position, state: *main.GameState) struct { player: ?*Player, distance: f32 } {
    var closestPlayer: ?*Player = null;
    var closestDistance: f32 = 0;
    for (state.players.items) |*player| {
        if (player.isDead) continue;
        const tempDistance = main.calculateDistance(player.position, position);
        if (closestPlayer == null or tempDistance < closestDistance) {
            closestPlayer = player;
            closestDistance = tempDistance;
        }
    }
    return .{ .player = closestPlayer, .distance = closestDistance };
}

fn ninjaDogDeathCutSprites(player: *Player, state: *main.GameState) !void {
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.chestArmorImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = player.position,
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.headLayer2ImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = .{ .x = player.position.x, .y = player.position.y - 8 },
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.feetImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = .{ .x = player.position.x, .y = player.position.y + 8 },
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = player.paintData.weaponImageIndex },
        .cutAngle = 1,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = player.position,
    });
}

pub fn getPlayerDamage(player: *Player) u32 {
    return @as(u32, @intFromFloat(@round(@as(f32, @floatFromInt(player.damage)) * player.damagePerCentFactor)));
}

pub fn getPlayerTotalHp(player: *Player) u32 {
    if (player.isDead) return 0;
    var hp: u32 = 1;
    if (player.equipment.equipmentSlotsData.body != null and player.equipment.equipmentSlotsData.body.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.body.?.effectType.hp.hp;
    }
    if (player.equipment.equipmentSlotsData.head != null and player.equipment.equipmentSlotsData.head.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.head.?.effectType.hp.hp;
    }
    if (player.equipment.equipmentSlotsData.feet != null and player.equipment.equipmentSlotsData.feet.?.effectType == .hp) {
        hp += player.equipment.equipmentSlotsData.feet.?.effectType.hp.hp;
    }
    return hp;
}

pub fn determinePlayerUxPositions(state: *main.GameState) void {
    var scale: f32 = 1;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    var diffScale: f32 = 0;
    if (state.players.items.len <= 2) {
        diffScale = state.windowData.widthFloat / state.windowData.heightFloat;
        if (diffScale > 1.2) {
            scale = @max(1.0, @min(2.0, 1 + (diffScale - 1.2) * 2.0));
        }
    }

    const height = scale / 4.0;
    const width = height / onePixelYInVulkan * onePixelXInVulkan;
    const playerPosX = [_]f32{ -0.99, 0.99 - width };
    const playerPosY = [_]f32{ 0 - scale / 2.0, -1, 0 };

    for (state.players.items, 0..) |*player, index| {
        player.uxData.vulkanScale = scale;
        player.uxData.vulkanTopLeft.x = playerPosX[@mod(index, 2)];
        if (state.players.items.len <= 2) {
            player.uxData.vulkanTopLeft.y = playerPosY[0];
        } else {
            player.uxData.vulkanTopLeft.y = playerPosY[@mod(@divFloor(index, 2), 2) + 1];
        }
    }
}

pub fn playerLeave(playerIndex: usize, state: *main.GameState) !void {
    if (state.players.items.len > 1 and playerIndex < state.players.items.len) {
        var removed = state.players.swapRemove(playerIndex);
        if (state.players.items.len == 1) {
            state.players.items[0].inputData.inputDevice = null;
        } else {
            if (removed.inputData.inputDevice != null and removed.inputData.inputDevice.? == .keyboard) {
                var keyBoardPlayerCount: u32 = 0;
                for (state.players.items) |*player| {
                    if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .keyboard) {
                        keyBoardPlayerCount += 1;
                    }
                }
                if (keyBoardPlayerCount == 1) {
                    for (state.players.items) |*player| {
                        if (player.inputData.inputDevice != null and player.inputData.inputDevice.? == .keyboard) {
                            player.inputData.holdingKeySinceForLeave = null;
                            player.inputData.inputDevice.?.keyboard = null;
                        }
                    }
                }
            }
        }
        destroyPlayer(&removed, state);
        main.adjustZoom(state);
        if (state.level <= 1 and state.round <= 1) {
            state.statistics.currentRunStats.playerCount = @intCast(state.players.items.len);
        } else {
            state.statistics.currentRunStats.playerCount = 0;
        }
    }
}

pub fn playerJoin(playerInputData: inputZig.PlayerInputData, state: *main.GameState) !void {
    if (playerInputData.inputDevice == null) return error.invalidPlayerInputData;
    if (state.players.items.len > 1 and playerInputData.inputDevice.? == .keyboard) {
        for (state.players.items) |*otherPlayer| {
            if (otherPlayer.inputData.inputDevice != null and otherPlayer.inputData.inputDevice.? == .keyboard and
                otherPlayer.inputData.inputDevice.?.keyboard == playerInputData.inputDevice.?.keyboard)
            {
                std.debug.print("prevent two player with same input\n", .{});
                return;
            }
        }
    }
    std.debug.print("player join: {}\n", .{playerInputData.inputDevice.?});
    try state.players.append(createPlayer(state.allocator));
    const player: *Player = &state.players.items[state.players.items.len - 1];
    assignPlayerColor(player, state);
    if (state.gameOver) player.isDead = true;
    player.inputData = playerInputData;
    for (0..state.players.items.len - 1) |index| {
        const otherPlayer = &state.players.items[index];
        if (otherPlayer.inputData.inputDevice == null) {
            if (player.inputData.inputDevice.? == .gamepad) {
                otherPlayer.inputData.inputDevice = .{ .keyboard = null };
            } else if (player.inputData.inputDevice.? == .keyboard) {
                if (player.inputData.inputDevice.?.keyboard == 0) {
                    otherPlayer.inputData.inputDevice = .{ .keyboard = 1 };
                } else {
                    otherPlayer.inputData.inputDevice = .{ .keyboard = 0 };
                }
                otherPlayer.uxData.visualizeMovementKeys = true;
                otherPlayer.uxData.visualizeChoiceKeys = true;
            }
        } else if (player.inputData.inputDevice.? == .keyboard and otherPlayer.inputData.inputDevice.? == .keyboard and otherPlayer.inputData.inputDevice.?.keyboard == null) {
            if (player.inputData.inputDevice.?.keyboard == 0) {
                otherPlayer.inputData.inputDevice = .{ .keyboard = 1 };
            } else {
                otherPlayer.inputData.inputDevice = .{ .keyboard = 0 };
            }
            otherPlayer.uxData.visualizeMovementKeys = true;
            otherPlayer.uxData.visualizeChoiceKeys = true;
        }
    }
    player.inputData.lastInputTime = state.gameTime;
    if (state.level <= 1 and state.round <= 1) {
        state.statistics.currentRunStats.playerCount = @intCast(state.players.items.len);
    } else {
        state.statistics.currentRunStats.playerCount = 0;
    }
    equipmentZig.equipStarterEquipment(player);
    try movePieceZig.setupMovePieces(player, state);
    main.adjustZoom(state);
}

fn assignPlayerColor(player: *Player, state: *main.GameState) void {
    const availableColor = [_][4]f32{
        .{ 0, 0, 0.5, 1 },
        .{ 0, 0.2, 0, 1 },
        .{ 0.8, 0, 0, 1 },
        .{ 1, 1, 1, 1 },
    };
    for (availableColor) |color| {
        var colorIsFree = true;
        for (state.players.items) |*otherPlayer| {
            if (otherPlayer == player) continue;
            const otherColor = otherPlayer.uxData.visualizeChoosenMovePieceColor;
            if (otherColor[0] == color[0] and otherColor[1] == color[1] and otherColor[2] == color[2]) {
                colorIsFree = false;
                break;
            }
        }
        if (colorIsFree) {
            player.uxData.visualizeChoosenMovePieceColor = color;
            break;
        }
    }
}
