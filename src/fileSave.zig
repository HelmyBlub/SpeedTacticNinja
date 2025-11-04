const std = @import("std");
const main = @import("main.zig");
const shopZig = @import("shop.zig");
const playerZig = @import("player.zig");
const inputZig = @import("input.zig");
const equipmentZig = @import("equipment.zig");
const movePieceZig = @import("movePiece.zig");
const achievementZig = @import("achievement.zig");
const modeSelectZig = @import("modeSelect.zig");

const FILE_VERSION_SAVE_RUN: u8 = 0;
const FILE_NAME_SAVE_RUN = "currenRun.dat";

const FILE_VERSION_SETTINGS: u8 = 0;
const FILE_NAME_SETTINGS = "settings.dat";

pub fn getSavePath(allocator: std.mem.Allocator, filename: []const u8) ![]const u8 {
    const directory_path = try getSaveDirectoryPath(allocator);
    defer allocator.free(directory_path);
    try std.fs.cwd().makePath(directory_path);

    const full_path = try std.fs.path.join(allocator, &.{ directory_path, filename });
    return full_path;
}

pub fn getSaveDirectoryPath(allocator: std.mem.Allocator) ![]const u8 {
    const game_name = "SpeedTacticNinja";
    const save_folder = "saves";

    const base_dir = try std.fs.getAppDataDir(allocator, game_name);
    defer allocator.free(base_dir);

    const directory_path = try std.fs.path.join(allocator, &.{ base_dir, save_folder });
    return directory_path;
}

pub fn deleteFile(filename: []const u8, allocator: std.mem.Allocator) !void {
    const filepath = try getSavePath(allocator, filename);
    defer allocator.free(filepath);
    try std.fs.deleteFileAbsolute(filepath);
}

pub fn loadSettingsFromFile(state: *main.GameState) !void {
    const filepath = try getSavePath(state.allocator, FILE_NAME_SETTINGS);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = file.reader();
    const fileVersion = try reader.readByte();
    if (fileVersion != FILE_VERSION_SETTINGS) {
        // do stuff if different versions exist
    }
    for (&state.uxData.settingsMenuUx.uiTabs) |*tab| {
        for (tab.uiElements) |*uiElement| {
            switch (uiElement.typeData) {
                .holdButton, .text => {},
                .checkbox => |*data| {
                    const checked = try reader.readInt(u8, .little);
                    data.checked = if (checked != 0) true else false;
                    try data.onSetChecked(data.checked, state);
                },
                .slider => |*data| {
                    const valuePerCent: f32 = @max(0, @min(1, @as(f32, @bitCast(try reader.readInt(u32, .little)))));
                    data.valuePerCent = valuePerCent;
                    if (data.onStopHolding) |stopHolding| {
                        try stopHolding(data.valuePerCent, uiElement, state);
                    } else if (data.onChange) |change| {
                        try change(data.valuePerCent, uiElement, state);
                    }
                },
            }
        }
    }
    state.highestNewGameDifficultyBeaten = @max(-1, @min(1000, try reader.readInt(i32, .little)));
    state.highestLevelBeaten = @min(main.LEVEL_COUNT, try reader.readInt(u32, .little));
    for (state.achievements.values, 0..) |value, achievementIndex| {
        if (value.displayInAchievementsMode) {
            const checked = try reader.readInt(u8, .little);
            state.achievements.values[achievementIndex].achieved = if (checked != 0) true else false;
        }
    }
    state.modeSelect.highscoreMazeMode = try reader.readInt(u32, .little);
}

pub fn saveSettingsToFile(state: *main.GameState) !void {
    const filepath = try getSavePath(state.allocator, FILE_NAME_SETTINGS);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.writeByte(FILE_VERSION_SETTINGS);
    for (state.uxData.settingsMenuUx.uiTabs) |tab| {
        for (tab.uiElements) |uiElement| {
            switch (uiElement.typeData) {
                .holdButton, .text => {},
                .checkbox => |data| {
                    try writer.writeInt(u8, if (data.checked) 1 else 0, .little);
                },
                .slider => |data| {
                    try writer.writeInt(u32, @bitCast(data.valuePerCent), .little);
                },
            }
        }
    }
    try writer.writeInt(i32, @bitCast(state.highestNewGameDifficultyBeaten), .little);
    try writer.writeInt(u32, @bitCast(state.highestLevelBeaten), .little);
    for (state.achievements.values) |value| {
        if (value.displayInAchievementsMode) {
            try writer.writeInt(u8, if (value.achieved) 1 else 0, .little);
        }
    }
    try writer.writeInt(u32, @bitCast(state.modeSelect.highscoreMazeMode), .little);
}

pub fn loadCurrentRunFromFile(state: *main.GameState) !void {
    const filepath = try getSavePath(state.allocator, FILE_NAME_SAVE_RUN);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().openFile(filepath, .{});
    defer file.close();

    const reader = file.reader();
    const safeFileVersion = try reader.readByte();
    if (safeFileVersion != FILE_VERSION_SAVE_RUN) {
        // std.debug.print("not loading outdated save file version");
    }

    const timestamp = std.time.milliTimestamp();
    {
        const level = try reader.readInt(u32, .little);
        const newGamePlus = try reader.readInt(u32, .little);
        const timePlayed = try reader.readInt(i64, .little);
        const continueDataBossesAced = try reader.readInt(u32, .little);
        const continueDataFreeContinues = try reader.readInt(u32, .little);
        const continueDataPaidContinues = try reader.readInt(u32, .little);
        const continueDataNextBossAceFreeContinue = try reader.readInt(u32, .little);
        const continueDataNextBossAceFreeContinueIncrease = try reader.readInt(u32, .little);
        try main.runStart(state, newGamePlus);
        state.modeSelect.selectedMode = .{ .newGamePlus = state.newGamePlus };
        state.statistics.active = false;
        state.statistics.runStartedTime = timestamp - timePlayed;
        state.level = level - 1;
        state.continueData.bossesAced = continueDataBossesAced;
        state.continueData.freeContinues = continueDataFreeContinues;
        state.continueData.paidContinues = continueDataPaidContinues;
        state.continueData.nextBossAceFreeContinue = continueDataNextBossAceFreeContinue;
        state.continueData.nextBossAceFreeContinueIncrease = continueDataNextBossAceFreeContinueIncrease;
    }
    const playerCount = try reader.readInt(usize, .little);
    for (0..playerCount) |index| {
        const inputDeviceData = try readInputDeviceData(reader, state);
        if (state.players.items.len <= index) {
            try playerZig.playerJoin(.{ .inputDevice = inputDeviceData }, state);
        } else {
            state.players.items[index].inputData.inputDevice = inputDeviceData;
        }
        const player: *playerZig.Player = &state.players.items[index];
        player.money = try reader.readInt(u32, .little);
        try readPlayerMovePieces(player, reader, state);
        try readEquipmentSlotData(player, reader, state);
    }
    try readTimeStatsData(reader, state);
    try readGameModeData(reader, state);
    try shopZig.startShoppingPhase(state, true);
    try readShopBuyOptions(reader, state);
    try readAchievementData(reader, state);
}

pub fn saveCurrentRunToFile(state: *main.GameState) !void {
    if (state.autoTest.mode == .replay or state.autoTest.zigTest) return;
    if ((state.modeSelect.selectedMode == .newGamePlus or state.modeSelect.selectedMode == .custom) and state.gameOver) try main.executeContinue(state);
    if ((state.modeSelect.selectedMode != .newGamePlus and state.modeSelect.selectedMode != .custom) or state.gameOver or state.gamePhase == .finished or state.level <= 2) {
        deleteFile(FILE_NAME_SAVE_RUN, state.allocator) catch {};
        return;
    }
    if (state.modeSelect.selectedMode != .newGamePlus and state.modeSelect.selectedMode != .custom) return;
    const filepath = try getSavePath(state.allocator, FILE_NAME_SAVE_RUN);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const timestamp = std.time.milliTimestamp();
    const writer = file.writer();
    _ = try writer.writeByte(FILE_VERSION_SAVE_RUN);
    const saveLevel = if (state.gamePhase == .shopping) state.level + 1 else state.level;
    _ = try writer.writeInt(u32, saveLevel, .little);
    _ = try writer.writeInt(u32, state.newGamePlus, .little);
    const timePlayed: i64 = timestamp - state.statistics.runStartedTime;
    _ = try writer.writeInt(i64, timePlayed, .little);
    _ = try writer.writeInt(u32, state.continueData.bossesAced, .little);
    _ = try writer.writeInt(u32, state.continueData.freeContinues, .little);
    _ = try writer.writeInt(u32, state.continueData.paidContinues, .little);
    _ = try writer.writeInt(u32, state.continueData.nextBossAceFreeContinue, .little);
    _ = try writer.writeInt(u32, state.continueData.nextBossAceFreeContinueIncrease, .little);

    _ = try writer.writeInt(usize, state.players.items.len, .little);
    for (state.players.items) |*player| {
        try writeInputDeviceData(player, writer);
        if (state.gamePhase != .shopping) {
            _ = try writer.writeInt(u32, player.moneyOnShopLeftForSave, .little);
        } else {
            _ = try writer.writeInt(u32, player.money, .little);
        }
        try writePlayerMovePieces(player, writer);
        try writeEquipmentSlotData(player.equipment.equipmentSlotsData.head, writer);
        try writeEquipmentSlotData(player.equipment.equipmentSlotsData.body, writer);
        try writeEquipmentSlotData(player.equipment.equipmentSlotsData.feet, writer);
        try writeEquipmentSlotData(player.equipment.equipmentSlotsData.weapon, writer);
    }
    try writeTimeStatsData(writer, state);
    try writeGameModeData(writer, state);
    try writeShopBuyOptions(writer, state);
    try writeAchievementData(writer, state);
}

///only for mode newGamePlus and custom
fn writeGameModeData(writer: anytype, state: *main.GameState) !void {
    const gameModeWriteValue: u8 = @as(u8, @intFromEnum(state.modeSelect.selectedMode));
    try writer.writeInt(u8, gameModeWriteValue, .little);
    if (state.modeSelect.selectedMode == .custom) {
        const modeCustomDataConfig = state.modeSelect.modeCustomData.config;
        try writer.writeInt(u32, modeCustomDataConfig.additionalFreeContinues, .little);
        try writer.writeInt(i32, modeCustomDataConfig.bonusTimePerRoundFinished, .little);
        try writer.writeInt(u32, modeCustomDataConfig.maxEnemyLevelStartCount, .little);
        try writer.writeInt(u32, modeCustomDataConfig.minEnemyLevelStartCount, .little);
        try writer.writeInt(i32, modeCustomDataConfig.minimalTimePerRequiredRounds, .little);
        try writer.writeInt(u32, @bitCast(modeCustomDataConfig.moneyGainMultiply), .little);
        try writer.writeInt(i64, modeCustomDataConfig.playerImmunityFrames, .little);
        try writer.writeInt(u32, modeCustomDataConfig.playerMovePieceRandom, .little);
        try writer.writeInt(usize, modeCustomDataConfig.roundToReachForNextLevel, .little);
        try writer.writeInt(u32, modeCustomDataConfig.shopMinBuyOptions, .little);
    }
}

///only for mode newGamePlus and custom
fn readGameModeData(reader: anytype, state: *main.GameState) !void {
    const modeEnumInt = try reader.readInt(u8, .little);
    const mode: modeSelectZig.ModeEnum = try std.meta.intToEnum(modeSelectZig.ModeEnum, modeEnumInt);
    if (mode == .custom) {
        state.modeSelect.selectedMode = .custom;
        const modeCustomDataConfig = &state.modeSelect.modeCustomData.config;
        modeCustomDataConfig.additionalFreeContinues = try reader.readInt(u32, .little);
        modeCustomDataConfig.bonusTimePerRoundFinished = try reader.readInt(i32, .little);
        modeCustomDataConfig.maxEnemyLevelStartCount = try reader.readInt(u32, .little);
        modeCustomDataConfig.minEnemyLevelStartCount = try reader.readInt(u32, .little);
        modeCustomDataConfig.minimalTimePerRequiredRounds = try reader.readInt(i32, .little);
        modeCustomDataConfig.moneyGainMultiply = @max(0.2, @min(10, @as(f32, @bitCast(try reader.readInt(u32, .little)))));
        modeCustomDataConfig.playerImmunityFrames = try reader.readInt(i64, .little);
        modeCustomDataConfig.playerMovePieceRandom = try reader.readInt(u32, .little);
        modeCustomDataConfig.roundToReachForNextLevel = try reader.readInt(usize, .little);
        modeCustomDataConfig.shopMinBuyOptions = try reader.readInt(u32, .little);
        state.config = modeCustomDataConfig.*;
    }
}

fn writeAchievementData(writer: anytype, state: *main.GameState) !void {
    var iter = state.achievements.iterator();
    while (iter.next()) |achievement| {
        _ = try writer.writeInt(u8, if (achievement.value.trackingActive) 1 else 0, .little);
    }
}

fn readAchievementData(reader: anytype, state: *main.GameState) !void {
    var iter = state.achievements.iterator();
    while (iter.next()) |achievement| {
        const active = try reader.readInt(u8, .little);
        achievement.value.trackingActive = if (active != 0) true else false;
    }
}

fn writeTimeStatsData(writer: anytype, state: *main.GameState) !void {
    if (state.shop.backwardsShopEnterTime) |time| {
        const passedTime = std.time.milliTimestamp() - time;
        state.statistics.currentRunStats.levelDatas.items[state.level - 1].shoppingTime += passedTime;
        state.shop.backwardsShopEnterTime = null;
    } else if (state.gamePhase == .shopping and state.level >= 2) {
        const current = &state.statistics.currentRunStats.levelDatas.items[state.level - 1];
        const passedTime = std.time.milliTimestamp() - state.statistics.runStartedTime - current.totalTime;
        current.shoppingTime = passedTime;
    }
    _ = try writer.writeInt(u8, if (state.statistics.active) 1 else 0, .little);
    const currentRunStats = state.statistics.currentRunStats;
    _ = try writer.writeInt(u32, currentRunStats.playerCount, .little);
    _ = try writer.writeInt(u32, currentRunStats.newGamePlus, .little);
    _ = try writer.writeInt(usize, currentRunStats.levelDatas.items.len, .little);
    for (currentRunStats.levelDatas.items) |levelData| {
        _ = try writer.writeInt(i64, levelData.time, .little);
        _ = try writer.writeInt(i64, levelData.totalTime, .little);
        _ = try writer.writeInt(i64, levelData.shoppingTime, .little);
        _ = try writer.writeInt(u32, levelData.round, .little);
    }
}

fn readTimeStatsData(reader: anytype, state: *main.GameState) !void {
    const active = try reader.readInt(u8, .little);
    state.statistics.active = if (active != 0) true else false;

    const currentRunStats = &state.statistics.currentRunStats;
    currentRunStats.playerCount = try reader.readInt(u32, .little);
    currentRunStats.newGamePlus = try reader.readInt(u32, .little);
    currentRunStats.levelDatas.clearRetainingCapacity();
    const levelDatasCount = try reader.readInt(usize, .little);

    for (0..levelDatasCount) |_| {
        try currentRunStats.levelDatas.append(.{
            .time = try reader.readInt(i64, .little),
            .totalTime = try reader.readInt(i64, .little),
            .shoppingTime = try reader.readInt(i64, .little),
            .round = try reader.readInt(u32, .little),
        });
    }
    state.statistics.totalShoppingTime = 0;
    for (currentRunStats.levelDatas.items) |level| {
        state.statistics.totalShoppingTime += level.shoppingTime;
    }
}

fn writeEquipmentSlotData(optEquipSlotData: ?equipmentZig.EquipmentSlotData, writer: anytype) !void {
    if (optEquipSlotData) |equipSlotData| {
        var optMatchingEquipIndex: ?u8 = null;
        for (equipmentZig.EQUIPMENT_SHOP_OPTIONS, 0..) |equipmentShopOption, equipIndex| {
            if (equipmentShopOption.equipment.imageIndex == equipSlotData.imageIndex) {
                optMatchingEquipIndex = @intCast(equipIndex);
                break;
            }
        }
        if (optMatchingEquipIndex) |matchingEquipIndex| {
            _ = try writer.writeInt(u8, matchingEquipIndex + 1, .little);
            if (equipSlotData.effectType == .hp) {
                _ = try writer.writeInt(u8, equipSlotData.effectType.hp.hp, .little);
            }
            if (equipSlotData.effectType == .damage) {
                _ = try writer.writeInt(u32, equipSlotData.effectType.damage.damage, .little);
            }
        } else {
            _ = try writer.writeInt(u8, 0, .little);
        }
    } else {
        _ = try writer.writeInt(u8, 0, .little);
    }
}

fn readEquipmentSlotData(player: *playerZig.Player, reader: anytype, state: *main.GameState) !void {
    for (0..4) |i| {
        const equipIndexAndNull = try reader.readInt(u8, .little);
        if (equipIndexAndNull != 0) {
            const equipIndex = equipIndexAndNull - 1;
            var equipOption = equipmentZig.getEquipmentOptionByIndexScaledToLevel(equipIndex, state.level);
            if (equipOption.equipment.effectType == .hp) {
                equipOption.equipment.effectType.hp.hp = try reader.readInt(u8, .little);
            }
            if (equipOption.equipment.effectType == .damage) {
                equipOption.equipment.effectType.damage.damage = try reader.readInt(u32, .little);
            }
            _ = equipmentZig.equip(equipOption.equipment, false, player);
        } else {
            if (i == 0) {
                equipmentZig.unequip(.head, player);
            } else if (i == 1) {
                equipmentZig.unequip(.body, player);
            }
        }
    }
}

fn writePlayerMovePieces(player: *playerZig.Player, writer: anytype) !void {
    _ = try writer.writeInt(usize, player.totalMovePieces.items.len, .little);
    for (player.totalMovePieces.items) |movePiece| {
        _ = try writer.writeInt(usize, movePiece.steps.len, .little);
        for (movePiece.steps) |step| {
            _ = try writer.writeInt(u8, step.direction, .little);
            _ = try writer.writeInt(u8, step.stepCount, .little);
        }
    }
}

fn readPlayerMovePieces(player: *playerZig.Player, reader: anytype, state: *main.GameState) !void {
    for (player.totalMovePieces.items) |movePiece| {
        state.allocator.free(movePiece.steps);
    }
    player.totalMovePieces.clearRetainingCapacity();
    player.availableMovePieces.clearRetainingCapacity();
    player.moveOptions.clearRetainingCapacity();
    const movePieceCount = try reader.readInt(usize, .little);
    for (0..movePieceCount) |_| {
        const stepsCount = try reader.readInt(usize, .little);
        const steps: []movePieceZig.MoveStep = try state.allocator.alloc(movePieceZig.MoveStep, stepsCount);
        const movePiece: movePieceZig.MovePiece = .{ .steps = steps };
        for (steps) |*step| {
            step.direction = try reader.readInt(u8, .little);
            step.stepCount = try reader.readInt(u8, .little);
        }
        try player.totalMovePieces.append(movePiece);
    }
}

fn writeShopBuyOptions(writer: anytype, state: *main.GameState) !void {
    _ = try writer.writeInt(usize, state.shop.buyOptions.items.len, .little);
    for (state.shop.buyOptions.items) |buyOption| {
        var matchingEquipIndex: u8 = 0;
        if (buyOption.price > 0) {
            for (equipmentZig.EQUIPMENT_SHOP_OPTIONS, 0..) |equipmentShopOption, equipIndex| {
                if (equipmentShopOption.shopDisplayImage == buyOption.imageIndex) {
                    matchingEquipIndex = @intCast(equipIndex + 1);
                    break;
                }
            }
        }
        _ = try writer.writeInt(u8, matchingEquipIndex, .little);
    }
}

fn readShopBuyOptions(reader: anytype, state: *main.GameState) !void {
    const buyOptionCount = try reader.readInt(usize, .little);
    for (0..buyOptionCount) |index| {
        const equipIndexPlus1 = try reader.readInt(u8, .little);
        if (equipIndexPlus1 == 0) continue;
        if (index < state.shop.buyOptions.items.len) {
            const randomEquip = equipmentZig.getEquipmentOptionByIndexScaledToLevel(equipIndexPlus1 - 1, state.level);
            const pos = state.shop.buyOptions.items[index].tilePosition;
            state.shop.buyOptions.items[index] = .{
                .price = state.level * randomEquip.basePrice,
                .tilePosition = pos,
                .imageIndex = randomEquip.shopDisplayImage,
                .imageScale = randomEquip.imageScale,
                .equipment = randomEquip.equipment,
            };
        }
    }
}

fn writeInputDeviceData(player: *playerZig.Player, writer: anytype) !void {
    const inputDeviceInt: u8 = if (player.inputData.inputDevice) |device| @as(u8, @intFromEnum(device)) + 1 else 0;
    _ = try writer.writeInt(u8, inputDeviceInt, .little);
    if (inputDeviceInt > 0) {
        switch (player.inputData.inputDevice.?) {
            .gamepad => |id| {
                _ = try writer.writeInt(u32, id, .little);
            },
            .keyboard => |optId| {
                if (optId) |id| {
                    _ = try writer.writeInt(u32, id + 1, .little);
                } else {
                    _ = try writer.writeInt(u32, 0, .little);
                }
            },
        }
    }
}

fn readInputDeviceData(reader: anytype, state: *main.GameState) !?inputZig.InputDeviceData {
    const inputDeviceInt = try reader.readInt(u8, .little);
    var inputDeviceData: ?inputZig.InputDeviceData = null;
    if (inputDeviceInt > 0) {
        const inputDevice: inputZig.InputDevice = try std.meta.intToEnum(inputZig.InputDevice, inputDeviceInt - 1);
        switch (inputDevice) {
            .gamepad => {
                const gamepadId = try reader.readInt(u32, .little);
                inputDeviceData = .{ .gamepad = gamepadId };
                try state.inputJoinData.disconnectedGamepads.append(gamepadId);
            },
            .keyboard => {
                const keyboardMappingId = try reader.readInt(u32, .little);
                if (keyboardMappingId == 0) {
                    inputDeviceData = .{ .keyboard = null };
                } else {
                    if (keyboardMappingId <= inputZig.KEYBOARD_MAPPINGS.len) {
                        inputDeviceData = .{ .keyboard = keyboardMappingId - 1 };
                    }
                }
            },
        }
    }

    return inputDeviceData;
}
