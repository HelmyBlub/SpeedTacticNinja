const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");
const bossZig = @import("boss/boss.zig");
const movePieceZig = @import("movePiece.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const playerZig = @import("player.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const imageZig = @import("image.zig");
const windowSdlZig = @import("windowSdl.zig");
const sdl = windowSdlZig.sdl;
const shopZig = @import("shop.zig");
const equipmentZig = @import("equipment.zig");
const enemyObjectFallDownZig = @import("enemy/enemyObjectFallDown.zig");
const statsZig = @import("stats.zig");
const enemyZig = @import("enemy/enemy.zig");
const modeSelectCustomZig = @import("modeSelectCustom.zig");

pub const ModeSelectData = struct {
    modeStartRectangles: std.ArrayList(ModeStartRectangle) = undefined,
    selectedMode: ModeData = .none,
    highscoreMazeMode: u32 = 0,
    modeCustomData: modeSelectCustomZig.ModeCustomData = .{},
};

const ModeEnum = enum {
    none,
    newGamePlus,
    practice,
    pvp,
    achievements,
    maze,
    custom,
};

const ModeData = union(ModeEnum) {
    none,
    newGamePlus: u32,
    practice,
    pvp: ?usize, // last player index who won
    achievements: struct { rec: main.TileRectangle, playerCount: u32 = 0 }, // back to modeSelect rectangle
    maze,
    custom,
};

pub const ModePlayerData = union(ModeEnum) {
    none,
    newGamePlus,
    practice,
    pvp: ModePlayerDataPvp,
    achievements,
    maze,
    custom,
};

const ModePlayerDataPvp = struct {
    wins: u32 = 0,
    lastMoveTime: i64 = 0,
};

const ModeStartRectangle = struct {
    displayName: []const u8,
    deallocDisplayName: bool = false,
    rectangle: main.TileRectangle,
    playerOnRectangleCounter: u32 = 0,
    modeData: ModeData,
};

pub fn initModeSelectData(state: *main.GameState) !void {
    state.modeSelect.modeStartRectangles = std.ArrayList(ModeStartRectangle).init(state.allocator);
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Normal", .modeData = .{ .newGamePlus = 0 }, .rectangle = .{
        .pos = .{ .x = 4, .y = -4 },
        .height = 2,
        .width = 2,
    } });
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Practice", .modeData = .practice, .rectangle = .{
        .pos = .{ .x = -4, .y = -4 },
        .height = 2,
        .width = 2,
    } });
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "PvP", .modeData = .{ .pvp = null }, .rectangle = .{
        .pos = .{ .x = -7, .y = -4 },
        .height = 2,
        .width = 2,
    } });
    try state.modeSelect.modeStartRectangles.append(.{
        .displayName = "Achievements",
        .modeData = .{ .achievements = .{ .rec = .{ .pos = .{ .x = 3, .y = -5 }, .width = 2, .height = 2 } } },
        .rectangle = .{
            .pos = .{ .x = -7, .y = -1 },
            .height = 2,
            .width = 2,
        },
    });
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Custom", .modeData = .custom, .rectangle = .{
        .pos = .{ .x = -4, .y = 2 },
        .height = 2,
        .width = 2,
    } });
    try state.modeSelect.modeStartRectangles.append(.{ .displayName = "Maze", .modeData = .maze, .rectangle = .{
        .pos = .{ .x = -7, .y = 2 },
        .height = 2,
        .width = 2,
    } });
    if (state.highestNewGameDifficultyBeaten > -1) {
        for (0..@intCast(state.highestNewGameDifficultyBeaten + 1)) |_| {
            try addNextNewGamePlusMode(state);
        }
    }
}

pub fn addNextNewGamePlusMode(state: *main.GameState) !void {
    var nextNGPlus: u32 = 0;
    for (state.modeSelect.modeStartRectangles.items) |modeRec| {
        if (modeRec.modeData == .newGamePlus and modeRec.modeData.newGamePlus > nextNGPlus) nextNGPlus = modeRec.modeData.newGamePlus;
    }
    nextNGPlus += 1;
    if (nextNGPlus > state.highestNewGameDifficultyBeaten + 1) return;
    const length = 10 + std.math.log10(nextNGPlus);
    const stringAlloc = try state.allocator.alloc(u8, length);
    _ = try std.fmt.bufPrint(stringAlloc, "New Game+{d}", .{nextNGPlus});
    try state.modeSelect.modeStartRectangles.append(.{
        .displayName = stringAlloc,
        .deallocDisplayName = true,
        .modeData = .{ .newGamePlus = @intCast(nextNGPlus) },
        .rectangle = .{
            .pos = .{ .x = 4, .y = @as(i32, @intCast(nextNGPlus - 1)) * 3 - 1 },
            .height = 2,
            .width = 2,
        },
    });
}

pub fn setupVertices(state: *main.GameState) !void {
    if (state.gamePhase == .modeSelect) {
        const modeSelect = &state.modeSelect;
        switch (modeSelect.selectedMode) {
            .none => {
                for (modeSelect.modeStartRectangles.items) |mode| {
                    try paintVulkanZig.verticesForStairsWithText(mode.rectangle, mode.displayName, mode.playerOnRectangleCounter, state);
                }
            },
            .achievements => try verticesForAchievementMode(state),
            .custom => try modeSelectCustomZig.setupVerticesCustom(state),
            else => {},
        }
    } else {
        switch (state.modeSelect.selectedMode) {
            .practice => verticesForPracticeMode(state),
            .maze => try verticesForMazeMode(state),
            else => {},
        }
    }
}

pub fn destroyModeSelectData(state: *main.GameState) void {
    const modeSelect = &state.modeSelect;
    for (modeSelect.modeStartRectangles.items) |item| {
        if (item.deallocDisplayName) state.allocator.free(item.displayName);
    }
    modeSelect.modeStartRectangles.deinit();
}

pub fn onPlayerMoveActionFinished(player: *playerZig.Player, state: *main.GameState) !void {
    if (state.gamePhase != .modeSelect) return;
    switch (state.modeSelect.selectedMode) {
        .none => {
            for (state.modeSelect.modeStartRectangles.items) |*mode| {
                mode.playerOnRectangleCounter = 0;
                for (state.players.items) |*otherPlayer| {
                    const playerTile = main.gamePositionToTilePosition(otherPlayer.position);
                    if (main.isTilePositionInTileRectangle(playerTile, mode.rectangle)) {
                        mode.playerOnRectangleCounter += 1;
                    }
                }
                if (mode.playerOnRectangleCounter == state.players.items.len) {
                    try onStartMode(mode.modeData, state);
                    return;
                }
            }
        },
        .achievements => {
            state.modeSelect.selectedMode.achievements.playerCount = 0;
            for (state.players.items) |*otherPlayer| {
                const playerTile = main.gamePositionToTilePosition(otherPlayer.position);
                if (main.isTilePositionInTileRectangle(playerTile, state.modeSelect.selectedMode.achievements.rec)) {
                    state.modeSelect.selectedMode.achievements.playerCount += 1;
                }
            }
            if (state.modeSelect.selectedMode.achievements.playerCount == state.players.items.len) {
                try startModeSelect(state);
                return;
            }
        },
        .custom => try modeSelectCustomZig.onPlayerMoveActionFinished(player, state),
        else => {},
    }
}

pub fn startModeSelect(state: *main.GameState) !void {
    if (!state.autoTest.zigTest and (state.gameOver or state.gamePhase == .finished)) try statsZig.statsSaveOnRestart(state);
    state.uxData.achievementGained.clearRetainingCapacity();
    state.paused = false;
    state.suddenDeath = 0;
    state.pauseInputTime = null;
    state.gamePhase = .modeSelect;
    state.modeSelect.selectedMode = .none;
    state.gameOver = false;
    state.uxData.continueButtonHoldStart = null;
    mapTileZig.resetMapTiles(state.mapData.tiles);
    state.mapObjects.clearAndFree();
    bossZig.clearBosses(state);
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    for (state.players.items) |*player| {
        player.isDead = false;
        player.position.x = 0;
        player.position.y = 0;
        equipmentZig.equipStarterEquipment(player);
        try movePieceZig.setupMovePieces(player, state);
    }
    try mapTileZig.setMapRadius(7, 4, state);
    state.camera.position = .{ .x = 0, .y = 0 };
    mapTileZig.setMapType(.default, state);
    state.level = 0;
    main.adjustZoom(state);
}

fn onStartMode(modeData: ModeData, state: *main.GameState) !void {
    state.modeSelect.selectedMode = modeData;
    for (state.players.items) |*player| {
        player.modeData = .none;
    }
    switch (modeData) {
        .none => {},
        .newGamePlus => |data| try main.runStart(state, data),
        .practice => try main.runStart(state, 0),
        .pvp => try onStartModePvp(state),
        .achievements => {
            try mapTileZig.setMapRadius(9, 5, state);
            main.adjustZoom(state);
        },
        .maze => {
            try startMazeMode(state);
        },
        .custom => {
            try modeSelectCustomZig.startModeCustom(state);
        },
    }
}

fn startMazeMode(state: *main.GameState) !void {
    state.gamePhase = .combat;
    state.gameTime = 0;
    state.gameOver = false;
    state.level = 1;
    state.newGamePlus = 0;
    for (state.players.items) |*player| {
        try playerZig.resetPlayer(player, state);
    }
    try main.resetLevelData(state);
    const enemySpawnData = &state.enemyData.enemySpawnData;
    enemySpawnData.enemyEntries.clearRetainingCapacity();
    try enemySpawnData.enemyEntries.append(.{ .probability = 1, .enemy = enemyZig.createSpawnEnemyEntryEnemy(.waller, state) });
    enemyZig.calcAndSetEnemySpawnProbabilities(enemySpawnData);
    state.config.roundToReachForNextLevel = std.math.maxInt(usize);
    try main.startNextRound(state);
    playerZig.movePlayerToLevelSpawnPosition(state);
}

fn onStartModePvp(state: *main.GameState) !void {
    for (state.players.items) |*player| {
        player.modeData = .{ .pvp = .{ .wins = 0 } };
    }
    try startModePvp(state);
}

pub fn tick(state: *main.GameState) !void {
    switch (state.modeSelect.selectedMode) {
        .pvp => {
            if (state.players.items.len <= 1) return;
            for (state.players.items) |*player| {
                if (player.modeData != .pvp) {
                    player.modeData = .{ .pvp = .{ .wins = 0 } };
                    try startModePvp(state);
                    return;
                }
                if (player.modeData.pvp.lastMoveTime + 5_000 < state.gameTime) {
                    player.modeData.pvp.lastMoveTime += 5_000;
                    try enemyObjectFallDownZig.spawnFallDown(player.position, 5000, true, state);
                }
            }
            var aliveCount: u32 = 0;
            for (state.players.items) |player| {
                if (!player.isDead) aliveCount += 1;
            }
            if (aliveCount <= 1) {
                state.modeSelect.selectedMode.pvp = null;
                for (state.players.items, 0..) |*player, playerIndex| {
                    if (!player.isDead) {
                        state.modeSelect.selectedMode.pvp = playerIndex;
                        player.modeData.pvp.wins += 1;
                    }
                }
                try startModePvp(state);
            }
        },
        .maze => {
            try main.tickSuddenDeath(state);
            if (state.enemyData.enemies.items.len == 0) {
                if (@mod(state.round, 2) == 0) {
                    for (state.players.items) |*player| {
                        const movePiece = try movePieceZig.createRandomMovePiecePlayer(state.allocator, state);
                        try movePieceZig.addMovePiece(player, movePiece);
                    }
                }
                try main.startNextRound(state);
            }
            if (state.gameOver and state.modeSelect.highscoreMazeMode < state.round) {
                state.modeSelect.highscoreMazeMode = state.round;
            }
        },
        else => {},
    }
}

fn startModePvp(state: *main.GameState) !void {
    state.gamePhase = .combat;
    state.gameTime = 0;
    state.gameOver = false;
    for (state.players.items) |*player| {
        try playerZig.resetPlayer(player, state);
    }
    state.mapObjects.clearAndFree();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    state.spriteCutAnimations.clearRetainingCapacity();
    try mapTileZig.setMapRadius(4, 4, state);
    playerZig.movePlayerToLevelSpawnPosition(state);
}

fn verticesForAchievementMode(state: *main.GameState) !void {
    try paintVulkanZig.verticesForStairsWithText(
        state.modeSelect.selectedMode.achievements.rec,
        "Back",
        state.modeSelect.selectedMode.achievements.playerCount,
        state,
    );
    const startTopLeft: main.Position = .{
        .x = @floatFromInt(-9 * main.TILESIZE),
        .y = @floatFromInt(-4 * main.TILESIZE),
    };
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 7;
    const bossArray = bossZig.LEVEL_BOSS_DATA.values;
    const maxNewGamePlus: usize = @intCast(state.highestNewGameDifficultyBeaten + 2);
    var displayCount: f32 = 0;
    for (state.achievements.values) |achievement| {
        if (achievement.displayInAchievementsMode) {
            const displayPos: main.Position = .{
                .x = startTopLeft.x + displayCount * main.TILESIZE * 2,
                .y = startTopLeft.y,
            };
            var textDisplayPos: main.Position = .{
                .x = displayPos.x - main.TILESIZE / 2,
                .y = displayPos.y - main.TILESIZE / 4,
            };
            const alpha: f32 = if (achievement.achieved) 1 else 0.3;
            paintVulkanZig.verticesForComplexSprite(displayPos, imageZig.IMAGE_SHOP_PODEST, 1.5, 1.5, alpha, 0, false, false, state);
            if (achievement.displayImageIndex != null and achievement.achieved) {
                paintVulkanZig.verticesForComplexSprite(.{
                    .x = displayPos.x,
                    .y = displayPos.y - main.TILESIZE,
                }, achievement.displayImageIndex.?, achievement.displayScale, achievement.displayScale, alpha, 0, false, false, state);
                if (achievement.displayCharOnImage) |char| {
                    _ = fontVulkanZig.paintTextGameMap(char, .{
                        .x = displayPos.x - fontSize,
                        .y = displayPos.y - main.TILESIZE - fontSize,
                    }, fontSize * 2, textColor, state);
                }
            }
            if (achievement.displayName) |display| textDisplayPos.x += fontVulkanZig.paintTextGameMap(display, textDisplayPos, fontSize, textColor, state);
            displayCount += 1;
        }
    }
    for (0..maxNewGamePlus) |ngpIndex| {
        for (0..bossArray.len) |bossIndex| {
            var achieved = true;
            if (maxNewGamePlus - 1 == ngpIndex and @divFloor(state.highestLevelBeaten, 5) < bossIndex + 1) achieved = false;
            const alpha: f32 = if (achieved) 1 else 0.3;
            const displayPos: main.Position = .{
                .x = startTopLeft.x + @as(f32, @floatFromInt(bossIndex)) * main.TILESIZE * 2,
                .y = startTopLeft.y + @as(f32, @floatFromInt(ngpIndex + 1)) * main.TILESIZE * 3,
            };
            var textDisplayPos: main.Position = .{
                .x = displayPos.x - main.TILESIZE / 2,
                .y = displayPos.y - main.TILESIZE / 4,
            };
            paintVulkanZig.verticesForComplexSprite(displayPos, imageZig.IMAGE_SHOP_PODEST, 1.5, 1.5, alpha, 0, false, false, state);
            const offsetY: f32 = if (bossIndex == 9) main.TILESIZE / 2 else 0;
            if (achieved) {
                paintVulkanZig.verticesForComplexSprite(.{
                    .x = displayPos.x,
                    .y = displayPos.y - main.TILESIZE - offsetY,
                }, bossArray[bossIndex].imageIndex, 1, 1, alpha, 0, false, false, state);
            }
            textDisplayPos.x += fontVulkanZig.paintTextGameMap("NG+", textDisplayPos, fontSize, textColor, state);
            _ = try fontVulkanZig.paintNumberGameMap(ngpIndex, textDisplayPos, fontSize, textColor, state);
            if (!achieved) break;
        }
    }
}

fn verticesForMazeMode(state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const white: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 30 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const verticeData = &state.vkState.verticeData;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    var textWidth: f32 = 0;
    const levelPos: main.Position = .{
        .x = -0.99,
        .y = -0.99,
    };
    const paddingX = 2 * onePixelXInVulkan;
    const paddingY = 2 * onePixelYInVulkan;
    const roundStartX = textWidth;
    textWidth += fontVulkanZig.paintText("Round ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
    textWidth += try fontVulkanZig.paintNumber(state.round, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
    const roundRec: main.Rectangle = .{
        .pos = .{ .x = levelPos.x + roundStartX - paddingX, .y = levelPos.y - paddingY },
        .width = textWidth - roundStartX + paddingX * 3,
        .height = fontSize * onePixelYInVulkan + paddingY * 2,
    };
    paintVulkanZig.verticesForRectangle(roundRec.pos.x, roundRec.pos.y, roundRec.width, roundRec.height, white, &verticeData.lines, &verticeData.triangles);
    textWidth += paddingX * 6;

    const highscoreStartX = textWidth;
    textWidth += fontVulkanZig.paintText("Highscore: ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
    textWidth += try fontVulkanZig.paintNumber(state.modeSelect.highscoreMazeMode, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
    const highscoreRec: main.Rectangle = .{
        .pos = .{ .x = levelPos.x + highscoreStartX - paddingX, .y = levelPos.y - paddingY },
        .width = textWidth - highscoreStartX + paddingX * 3,
        .height = fontSize * onePixelYInVulkan + paddingY * 2,
    };
    paintVulkanZig.verticesForRectangle(highscoreRec.pos.x, highscoreRec.pos.y, highscoreRec.width, highscoreRec.height, white, &verticeData.lines, &verticeData.triangles);
}

fn verticesForPracticeMode(state: *main.GameState) void {
    const fontSize = 40 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const basePosition: main.Position = .{ .x = 0.5, .y = 0.99 - (fontSize * onePixelYInVulkan) * 2 };
    const key1Text = "F1  Next Level";
    const key1TextWidth = fontVulkanZig.getTextVulkanWidth(key1Text, fontSize / 2, state);
    const leftOffsetX = key1TextWidth + onePixelXInVulkan * 10;
    const key1Pos: main.Position = .{ .x = basePosition.x - leftOffsetX, .y = basePosition.y };
    paintVulkanZig.verticesForComplexSpriteVulkan(key1Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText(key1Text, .{
        .x = key1Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key1Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key2Pos: main.Position = .{ .x = basePosition.x - leftOffsetX, .y = basePosition.y + onePixelYInVulkan * fontSize };
    paintVulkanZig.verticesForComplexSpriteVulkan(key2Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F2  Shop", .{
        .x = key2Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key2Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key3Pos: main.Position = basePosition;
    paintVulkanZig.verticesForComplexSpriteVulkan(key3Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F3  NewGame++", .{
        .x = key3Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key3Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);

    const key4Pos: main.Position = .{ .x = basePosition.x, .y = basePosition.y + onePixelYInVulkan * fontSize };
    paintVulkanZig.verticesForComplexSpriteVulkan(key4Pos, imageZig.IMAGE_KEY_BLANK, fontSize, fontSize, 1, 0, false, false, state);
    _ = fontVulkanZig.paintText("F4  Restart", .{
        .x = key4Pos.x - onePixelXInVulkan * fontSize / 4 - onePixelXInVulkan * 2,
        .y = key4Pos.y - onePixelYInVulkan * fontSize / 4,
    }, fontSize / 2, .{ 1, 1, 1, 1 }, state);
}

pub fn handlePracticeModeKeys(event: sdl.SDL_Event, state: *main.GameState) !void {
    if (event.key.scancode == sdl.SDL_SCANCODE_F1) {
        if (state.level == main.LEVEL_COUNT) {
            state.level = 0;
        }
        if (state.gamePhase != .shopping) try shopZig.startShoppingPhase(state, false);
        try main.startNextLevel(state);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F2) {
        if (state.gamePhase != .shopping) state.level -= 1;
        try shopZig.startShoppingPhase(state, false);
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F3) {
        state.newGamePlus = @mod(state.newGamePlus + 1, 3);
        state.statistics.currentRunStats.newGamePlus = state.newGamePlus;
        if (state.gamePhase != .shopping) {
            state.level -= 1;
            try main.startNextLevel(state);
        }
    } else if (event.key.scancode == sdl.SDL_SCANCODE_F4) {
        try main.runStart(state, state.newGamePlus);
    }
}
