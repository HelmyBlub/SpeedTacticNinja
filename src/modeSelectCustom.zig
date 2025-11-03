const std = @import("std");
const main = @import("main.zig");
const mapTileZig = @import("mapTile.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const playerZig = @import("player.zig");
const achievementZig = @import("achievement.zig");
const soundMixerZig = @import("soundMixer.zig");

pub const ModeCustomData = struct {
    newGamePlus: u32 = 0,
    config: main.GameConfig = .{},
    stairs: struct { rec: main.TileRectangle = .{ .pos = .{ .x = 4, .y = 0 }, .width = 2, .height = 2 }, playerCount: u32 = 0 } = .{},
};

const CustomizeOption = struct {
    tilePos: main.TilePosition,
    name: []const u8,
    onChange: *const fn (leftInput: bool, state: *main.GameState) void,
    setupVerticesForValue: *const fn (option: CustomizeOption, state: *main.GameState) anyerror!void,
};

const CUSTOMIZE_OPTIONS = [_]CustomizeOption{
    .{ .name = "NG+", .tilePos = .{ .x = -4, .y = -5 }, .onChange = onChangeNewGamePlus, .setupVerticesForValue = setupVerticesNewGamePlus },
    .{ .name = "Rounds Required", .tilePos = .{ .x = -4, .y = -3 }, .onChange = onChangeRoundRequired, .setupVerticesForValue = setupVerticesRoundRequired },
    .{ .name = "Max Time Per Round", .tilePos = .{ .x = -4, .y = -1 }, .onChange = onChangeTimeForRequiredRound, .setupVerticesForValue = setupVerticesTimeForRequiredRound },
    .{ .name = "Time Additional Rounds", .tilePos = .{ .x = -4, .y = 1 }, .onChange = onChangeTimeForAdditionalRound, .setupVerticesForValue = setupVerticesTimeForAdditionalRound },
    .{ .name = "Min Enemy Start Level", .tilePos = .{ .x = -4, .y = 3 }, .onChange = onChangeMinEnemy, .setupVerticesForValue = setupVerticesMinEnemy },
    .{ .name = "Max Enemy Start Level", .tilePos = .{ .x = -4, .y = 5 }, .onChange = onChangeMaxEnemy, .setupVerticesForValue = setupVerticesMaxEnemy },
    .{ .name = "Money", .tilePos = .{ .x = 4, .y = -5 }, .onChange = onChangeMoneyGain, .setupVerticesForValue = setupVerticesMoneyGain },
    .{ .name = "Shop Min Buy Options", .tilePos = .{ .x = 4, .y = -3 }, .onChange = onChangeShopMinBuyOptions, .setupVerticesForValue = setupVerticesShopMinBuyOptions },
    .{ .name = "Free Continues", .tilePos = .{ .x = 4, .y = 3 }, .onChange = onChangeAddFreeContinues, .setupVerticesForValue = setupVerticesAddFreeContinues },
    .{ .name = "Move Piece Randomness", .tilePos = .{ .x = 4, .y = 5 }, .onChange = onChangeMovePieceRandomness, .setupVerticesForValue = setupVerticesMovePieceRandomness },
};

pub fn startModeCustom(state: *main.GameState) !void {
    try mapTileZig.setMapRadius(5, 5, state);
    main.adjustZoom(state);
    for (state.players.items) |*player| {
        player.position = .{ .x = 0, .y = 0 };
    }
}

pub fn setupVerticesCustom(state: *main.GameState) !void {
    const modeCustomData = &state.modeSelect.modeCustomData;
    try paintVulkanZig.verticesForStairsWithText(
        modeCustomData.stairs.rec,
        "Start",
        modeCustomData.stairs.playerCount,
        state,
    );
    for (CUSTOMIZE_OPTIONS) |option| {
        try setupVerticesCustomOptionDefault(option, state);
        try option.setupVerticesForValue(option, state);
    }
}

pub fn onPlayerMoveActionFinished(player: *playerZig.Player, state: *main.GameState) !void {
    const modeCustomData = &state.modeSelect.modeCustomData;
    modeCustomData.stairs.playerCount = 0;
    for (state.players.items) |*otherPlayer| {
        const playerTile = main.gamePositionToTilePosition(otherPlayer.position);
        if (main.isTilePositionInTileRectangle(playerTile, modeCustomData.stairs.rec)) {
            modeCustomData.stairs.playerCount += 1;
        }
    }
    if (modeCustomData.stairs.playerCount == state.players.items.len) {
        try main.runStart(state, modeCustomData.newGamePlus);
        achievementZig.stopTrackingAchievmentForThisRun(state);
        state.statistics.active = false;
        return;
    }

    const playerTile = main.gamePositionToTilePosition(player.position);
    for (CUSTOMIZE_OPTIONS) |option| {
        if (playerTile.x == option.tilePos.x - 1 and playerTile.y == option.tilePos.y) {
            option.onChange(true, state);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
        } else if (playerTile.x == option.tilePos.x + 1 and playerTile.y == option.tilePos.y) {
            option.onChange(false, state);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_SHOP_ACTION[0..], 0, 0.5);
        }
    }
}

fn setupVerticesCustomOptionDefault(option: CustomizeOption, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 12;
    const leftButtonPos: main.Position = .{
        .x = @floatFromInt((option.tilePos.x - 1) * main.TILESIZE - main.TILESIZE / 2),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE - main.TILESIZE / 2),
    };
    const rightButtonPos: main.Position = .{
        .x = @floatFromInt((option.tilePos.x + 1) * main.TILESIZE - main.TILESIZE / 2),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE - main.TILESIZE / 2),
    };

    paintVulkanZig.verticesForGameRectangle(.{ .pos = .{
        .x = rightButtonPos.x + main.TILESIZE / 2,
        .y = rightButtonPos.y + main.TILESIZE / 2,
    }, .width = main.TILESIZE, .height = main.TILESIZE }, .{ 1, 1, 1, 1 }, state);
    _ = fontVulkanZig.paintTextGameMap("+", .{
        .x = rightButtonPos.x,
        .y = rightButtonPos.y,
    }, main.TILESIZE * 0.9, textColor, state);

    paintVulkanZig.verticesForGameRectangle(.{ .pos = .{
        .x = leftButtonPos.x + main.TILESIZE / 2,
        .y = leftButtonPos.y + main.TILESIZE / 2,
    }, .width = main.TILESIZE, .height = main.TILESIZE }, .{ 1, 1, 1, 1 }, state);
    _ = fontVulkanZig.paintTextGameMap("-", .{
        .x = leftButtonPos.x,
        .y = leftButtonPos.y,
    }, main.TILESIZE * 0.9, textColor, state);

    const nameGameWidth = fontVulkanZig.getTextVulkanWidth(option.name, fontSize, state) / state.windowData.onePixelXInVulkan;
    var customFontSize: f32 = fontSize;
    var offsetX = -nameGameWidth / 2;
    if (nameGameWidth > main.TILESIZE * 5) {
        customFontSize = customFontSize / nameGameWidth * main.TILESIZE * 5;
        offsetX = -main.TILESIZE * 5 / 2;
    }
    _ = fontVulkanZig.paintTextGameMap(option.name, .{
        .x = leftButtonPos.x + main.TILESIZE + main.TILESIZE / 2 + offsetX,
        .y = leftButtonPos.y - customFontSize,
    }, customFontSize, textColor, state);
}

fn onChangeNewGamePlus(leftInput: bool, state: *main.GameState) void {
    if (leftInput) {
        state.modeSelect.modeCustomData.newGamePlus -|= 1;
    } else {
        state.modeSelect.modeCustomData.newGamePlus = @min(10, state.modeSelect.modeCustomData.newGamePlus + 1);
    }
}

fn setupVerticesNewGamePlus(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.newGamePlus, state);
}

fn onChangeRoundRequired(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.roundToReachForNextLevel = @max(config.roundToReachForNextLevel - 1, 2);
    } else {
        config.roundToReachForNextLevel = @min(100, config.roundToReachForNextLevel + 1);
    }
}

fn setupVerticesRoundRequired(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.roundToReachForNextLevel - 1, state);
}

fn onChangeTimeForRequiredRound(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.minimalTimePerRequiredRounds = @max(config.minimalTimePerRequiredRounds - 10000, 10_000);
    } else {
        config.minimalTimePerRequiredRounds = @min(300_000, config.minimalTimePerRequiredRounds + 10_000);
    }
}

fn setupVerticesTimeForRequiredRound(option: CustomizeOption, state: *main.GameState) anyerror!void {
    const displayValue = @divFloor(state.modeSelect.modeCustomData.config.minimalTimePerRequiredRounds, 1000);
    try displayNumberAtOption(option, displayValue, state);
}

fn onChangeTimeForAdditionalRound(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.bonusTimePerRoundFinished = @max(config.bonusTimePerRoundFinished - 1000, 1_000);
    } else {
        config.bonusTimePerRoundFinished = @min(60_000, config.bonusTimePerRoundFinished + 1_000);
    }
}

fn setupVerticesTimeForAdditionalRound(option: CustomizeOption, state: *main.GameState) anyerror!void {
    const displayValue = @divFloor(state.modeSelect.modeCustomData.config.bonusTimePerRoundFinished, 1000);
    try displayNumberAtOption(option, displayValue, state);
}

fn onChangeMinEnemy(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.minEnemyLevelStartCount = @max(config.minEnemyLevelStartCount - 1, 1);
    } else {
        config.minEnemyLevelStartCount = @min(100, config.minEnemyLevelStartCount + 1);
        if (config.maxEnemyLevelStartCount < config.minEnemyLevelStartCount) {
            config.maxEnemyLevelStartCount = config.minEnemyLevelStartCount;
        }
    }
}

fn setupVerticesMinEnemy(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.minEnemyLevelStartCount, state);
}

fn onChangeMaxEnemy(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.maxEnemyLevelStartCount = @max(config.maxEnemyLevelStartCount - 1, 1);
        if (config.maxEnemyLevelStartCount < config.minEnemyLevelStartCount) {
            config.minEnemyLevelStartCount = config.maxEnemyLevelStartCount;
        }
    } else {
        config.maxEnemyLevelStartCount = @min(100, config.maxEnemyLevelStartCount + 1);
    }
}

fn setupVerticesMaxEnemy(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.maxEnemyLevelStartCount, state);
}

fn onChangeMoneyGain(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.moneyGainMultiply = @round(@max(config.moneyGainMultiply - 0.1, 0.2) * 10) / 10;
    } else {
        config.moneyGainMultiply = @round(@min(10, config.moneyGainMultiply + 0.1) * 10) / 10;
    }
}

fn setupVerticesMoneyGain(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.moneyGainMultiply, state);
}

fn onChangeShopMinBuyOptions(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.shopMinBuyOptions = @max(config.shopMinBuyOptions - 1, 3);
    } else {
        config.shopMinBuyOptions = @min(6, config.shopMinBuyOptions + 1);
    }
}

fn setupVerticesShopMinBuyOptions(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.shopMinBuyOptions, state);
}

fn onChangeAddFreeContinues(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.additionalFreeContinues = @max(config.additionalFreeContinues -| 1, 0);
    } else {
        config.additionalFreeContinues = @min(99, config.additionalFreeContinues + 1);
    }
}

fn setupVerticesAddFreeContinues(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.additionalFreeContinues, state);
}

fn onChangeMovePieceRandomness(leftInput: bool, state: *main.GameState) void {
    const config = &state.modeSelect.modeCustomData.config;
    if (leftInput) {
        config.playerMovePieceRandom = @max(config.playerMovePieceRandom -| 1, 3);
    } else {
        config.playerMovePieceRandom = @min(6, config.playerMovePieceRandom + 1);
    }
}

fn setupVerticesMovePieceRandomness(option: CustomizeOption, state: *main.GameState) anyerror!void {
    try displayNumberAtOption(option, state.modeSelect.modeCustomData.config.playerMovePieceRandom, state);
}

fn displayNumberAtOption(option: CustomizeOption, number: anytype, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    var fontSize: f32 = main.TILESIZE;
    const startTopLeft: main.Position = .{
        .x = @floatFromInt(option.tilePos.x * main.TILESIZE),
        .y = @floatFromInt(option.tilePos.y * main.TILESIZE),
    };

    const widthPerDigit: f32 = fontSize * 0.7;
    var totalWidth: f32 = 0;
    if (@TypeOf(number) == f32) {
        totalWidth = widthPerDigit * @floor(3 + @log10(@max(1, @abs(number))));
    } else {
        const asFloat: f32 = @floatFromInt(number);
        totalWidth = widthPerDigit * @floor(1 + @log10(@max(1, @abs(asFloat))));
    }
    if (totalWidth > main.TILESIZE) {
        fontSize = fontSize / totalWidth * main.TILESIZE;
        totalWidth = main.TILESIZE;
    }

    _ = try fontVulkanZig.paintNumberGameMap(number, .{
        .x = startTopLeft.x - totalWidth / 2,
        .y = startTopLeft.y - fontSize / 2,
    }, fontSize, textColor, state);
}
