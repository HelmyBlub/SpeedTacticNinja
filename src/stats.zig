const std = @import("std");
const main = @import("main.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const windowSdlZig = @import("windowSdl.zig");
const fileSaveZig = @import("fileSave.zig");

pub const Statistics = struct {
    active: bool = true,
    runStartedTime: i64 = 0,
    runFinishedTime: i64 = 0,
    totalShoppingTime: i64 = 0,
    bestRunStats: std.ArrayList(BestRunsStatistics),
    currentRunStats: RunStatisctics,
    uxData: StatisticsUxData = .{},
};

pub const StatisticsUxData = struct {
    display: bool = false,
    vulkanPosition: main.Position = .{ .x = 0, .y = 0 },
    fontSize: f32 = 16,
    columnsData: []ColumnData = &COLUMNS_DATA,
    currentTimestamp: i64 = 0,
    displayBestRun: bool = true,
    displayNextLevelCount: u8 = 5,
    displayLevelCount: u8 = 25,
    displayGoldRun: bool = true,
    displayGoldRunValue: ?i64 = null,
    displayGoldRunLevel: u32 = 0,
    displayBestPossibleTime: bool = true,
    displayBestPossibleTimeValue: ?i64 = null,
    displayBestPossibleTimeLevel: u32 = 0,
    displayTimeInShop: bool = true,
    groupingLevelsInFive: bool = true,
};

const ColumnData = struct {
    name: []const u8,
    display: bool,
    pixelWidth: f32,
    setupVertices: *const fn (level: u32, levelDatas: []BestLevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void,
};

const BestRunsStatistics = struct {
    playerCount: u32,
    newGamePlus: u32,
    levelDatas: std.ArrayList(BestLevelStatistics),
};

const RunStatisctics = struct {
    playerCount: u32 = 0,
    newGamePlus: u32 = 0,
    levelDatas: std.ArrayList(LevelStatistics),
};

const BestLevelStatistics = struct {
    time: ?i64 = null,
    totalTime: ?i64 = null,
};

const LevelStatistics = struct {
    time: i64 = 0,
    totalTime: i64 = 0,
    round: u32 = 0,
    shoppingTime: i64 = 0,
};

const FILE_NAME_STATISTICS_DATA = "statistics.dat";
const SAFE_FILE_VERSION: u8 = 0;

var COLUMNS_DATA = [_]ColumnData{
    .{ .name = "Level", .display = true, .pixelWidth = 70, .setupVertices = setupVerticesLevel },
    .{ .name = "Time", .display = true, .pixelWidth = 100, .setupVertices = setupVerticesTime },
    .{ .name = "+/-", .display = true, .pixelWidth = 80, .setupVertices = setupVerticesTotalDiff },
    .{ .name = "Gold", .display = true, .pixelWidth = 80, .setupVertices = setupVerticesLevelDiff },
};

pub fn statsOnLevelFinished(state: *main.GameState) !void {
    const currentTime = std.time.milliTimestamp();
    if (state.level == main.LEVEL_COUNT and state.gamePhase == .finished) state.statistics.runFinishedTime = currentTime - state.statistics.runStartedTime;
    if (state.level == 0) return;
    const levelDatas = &state.statistics.currentRunStats.levelDatas;
    try levelDatas.append(.{});
    const currentLevelData = &levelDatas.items[levelDatas.items.len - 1];
    currentLevelData.totalTime = currentTime - state.statistics.runStartedTime;
    currentLevelData.round = state.round;
    if (state.level == 1) {
        currentLevelData.time = currentLevelData.totalTime;
    } else {
        const lastLevelData = &levelDatas.items[state.level - 2];
        currentLevelData.time = currentLevelData.totalTime - lastLevelData.totalTime - lastLevelData.shoppingTime;
    }
}

pub fn statsOnLevelShopFinishedAndNextLevelStart(state: *main.GameState) !void {
    if (state.level == 0) return;
    const levelDatas = &state.statistics.currentRunStats.levelDatas;
    const currentLevelData = &levelDatas.items[state.level - 1];
    const currentTime = std.time.milliTimestamp();
    currentLevelData.shoppingTime = currentTime - state.statistics.runStartedTime - currentLevelData.totalTime;
    state.statistics.totalShoppingTime += currentLevelData.shoppingTime;
}

pub fn statsSaveOnRestart(state: *main.GameState) !void {
    state.statistics.runStartedTime = std.time.milliTimestamp();
    state.statistics.totalShoppingTime = 0;
    if (!state.statistics.active or state.modeSelect.selectedMode != .newGamePlus) {
        state.statistics.active = true;
        return;
    }
    if (state.level == 0) return;
    const bestRunStats: []BestLevelStatistics = try getBestRunStats(state);
    const currentRunStats = &state.statistics.currentRunStats;
    var saveToFile = false;
    const isNewBestTotalTime = checkIfIsNewBestTotalTime(bestRunStats, state);
    for (bestRunStats, 0..) |*bestRunLevelData, index| {
        const levelBeat: u8 = if (state.gamePhase == .shopping or state.gamePhase == .finished) 1 else 0;
        if (state.level - 1 + levelBeat <= index) break;
        const currentRunLevelData = currentRunStats.levelDatas.items[index];
        if (bestRunLevelData.time == null or currentRunLevelData.time < bestRunLevelData.time.?) {
            bestRunLevelData.time = currentRunLevelData.time;
            saveToFile = true;
        }
        if (isNewBestTotalTime) {
            bestRunLevelData.totalTime = currentRunLevelData.totalTime;
            saveToFile = true;
        }
    }
    if (saveToFile) {
        try saveStatisticsDataToFile(state);
    }
    state.statistics.active = true;
}

fn checkIfIsNewBestTotalTime(levelDatas: []BestLevelStatistics, state: *main.GameState) bool {
    var isNewBestTotal: bool = false;
    if (state.level <= 1) return false;
    var currentTotalTime: i64 = 0;
    if (state.gamePhase == .finished) {
        currentTotalTime = state.statistics.runFinishedTime;
    } else if (state.gamePhase == .shopping) {
        currentTotalTime = state.statistics.currentRunStats.levelDatas.items[state.level - 1].totalTime;
    } else {
        currentTotalTime = state.statistics.currentRunStats.levelDatas.items[state.level - 2].totalTime;
    }
    if (state.gamePhase == .shopping or state.gamePhase == .finished) {
        var hasReachedHigherLevelBefore = false;
        if (levelDatas.len > state.level) {
            const nextLevelData = levelDatas[state.level];
            if (nextLevelData.totalTime != null) {
                hasReachedHigherLevelBefore = true;
            }
        }
        if (!hasReachedHigherLevelBefore) {
            const levelData = levelDatas[state.level - 1];
            if (levelData.totalTime == null or currentTotalTime < levelData.totalTime.?) {
                isNewBestTotal = true;
            }
        }
    } else {
        var hasReachedHigherLevelBefore = false;
        if (levelDatas.len > state.level) {
            const currentLevelData = levelDatas[state.level - 1];
            if (currentLevelData.totalTime != null) {
                hasReachedHigherLevelBefore = true;
            }
        }
        if (!hasReachedHigherLevelBefore and state.level > 1) {
            const highestDefeatedLevelData = levelDatas[state.level - 2];
            if (highestDefeatedLevelData.totalTime == null or currentTotalTime < highestDefeatedLevelData.totalTime.?) {
                isNewBestTotal = true;
            }
        }
    }
    return isNewBestTotal;
}

pub fn createStatistics(allocator: std.mem.Allocator) Statistics {
    return Statistics{
        .active = true,
        .bestRunStats = std.ArrayList(BestRunsStatistics).init(allocator),
        .currentRunStats = .{ .levelDatas = std.ArrayList(LevelStatistics).init(allocator) },
    };
}

pub fn destroyAndSave(state: *main.GameState) !void {
    if (!state.autoTest.zigTest and (state.gameOver or state.gamePhase == .finished)) try statsSaveOnRestart(state); // else saved in current run

    for (state.statistics.bestRunStats.items) |*forPlayerCount| {
        forPlayerCount.levelDatas.deinit();
    }
    state.statistics.bestRunStats.deinit();
    state.statistics.currentRunStats.levelDatas.deinit();
}

pub fn setupVertices(state: *main.GameState) !void {
    if (state.modeSelect.selectedMode != .newGamePlus and state.modeSelect.selectedMode != .custom) return;
    if (!state.statistics.uxData.display) return;
    if (state.level == 0) return;
    state.statistics.uxData.currentTimestamp = std.time.milliTimestamp();
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const topLeft: main.Position = state.statistics.uxData.vulkanPosition;
    const bestRunStats: []BestLevelStatistics = try getBestRunStats(state);
    const currentRunStats = state.statistics.currentRunStats.levelDatas.items;
    state.statistics.uxData.fontSize = 16 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const fontSize = state.statistics.uxData.fontSize;
    const vulkanFontSize = fontSize * onePixelYInVulkan;
    var columnOffsetX: f32 = 0;
    if (state.statistics.active) {
        if (state.statistics.currentRunStats.playerCount != 1) {
            const playerCountWidth = fontVulkanZig.paintText("Stats for player count: ", .{
                .x = topLeft.x,
                .y = topLeft.y - vulkanFontSize,
            }, fontSize, textColor, state);
            if (state.statistics.currentRunStats.playerCount == 0) {
                _ = fontVulkanZig.paintText("Mixed", .{
                    .x = topLeft.x + playerCountWidth,
                    .y = topLeft.y - vulkanFontSize,
                }, fontSize, textColor, state);
            } else {
                _ = try fontVulkanZig.paintNumber(state.statistics.currentRunStats.playerCount, .{
                    .x = topLeft.x + playerCountWidth,
                    .y = topLeft.y - vulkanFontSize,
                }, fontSize, textColor, state);
            }
        }
    } else {
        _ = fontVulkanZig.paintText("Will not be saved", .{
            .x = topLeft.x,
            .y = topLeft.y - vulkanFontSize,
        }, fontSize, textColor, state);
    }
    for (state.statistics.uxData.columnsData) |column| {
        if (!column.display) continue;
        const columnWidth = column.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const textWidht = fontVulkanZig.getTextVulkanWidth(column.name, fontSize, state);
        _ = fontVulkanZig.paintText(column.name, .{
            .x = topLeft.x + columnOffsetX + columnWidth - textWidht,
            .y = topLeft.y,
        }, fontSize, textColor, state);
        columnOffsetX += columnWidth;
    }
    var firstDisplayLevelWithoutMult: usize = 0;
    const groupingMultiplay: usize = if (state.statistics.uxData.groupingLevelsInFive) 5 else 1;
    if (state.level > state.statistics.uxData.displayLevelCount) {
        if (state.statistics.uxData.groupingLevelsInFive) {
            firstDisplayLevelWithoutMult = @divFloor(state.level + 4 - state.statistics.uxData.displayLevelCount, groupingMultiplay);
        } else {
            firstDisplayLevelWithoutMult = state.level - state.statistics.uxData.displayLevelCount;
        }
    } else {
        firstDisplayLevelWithoutMult = 1;
    }
    var lastDisplayLevelWithoutMultPlusOne: usize = 0;
    if (state.statistics.uxData.groupingLevelsInFive) {
        lastDisplayLevelWithoutMultPlusOne = @min(@divFloor(main.LEVEL_COUNT, groupingMultiplay), @divFloor(state.level + 4 + state.statistics.uxData.displayNextLevelCount, groupingMultiplay)) + 1;
    } else {
        lastDisplayLevelWithoutMultPlusOne = @min(main.LEVEL_COUNT, state.level + state.statistics.uxData.displayNextLevelCount) + 1;
    }
    for (firstDisplayLevelWithoutMult..lastDisplayLevelWithoutMultPlusOne) |levelWithoutMult| {
        const level = groupingMultiplay * levelWithoutMult;
        const row: f32 = @as(f32, @floatFromInt(levelWithoutMult - firstDisplayLevelWithoutMult)) + 1;
        columnOffsetX = 0;
        for (state.statistics.uxData.columnsData) |column| {
            if (!column.display) continue;
            try column.setupVertices(@intCast(level), bestRunStats, .{ .x = topLeft.x + columnOffsetX, .y = topLeft.y + row * vulkanFontSize }, column, state);
            columnOffsetX += column.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        }
    }
    var currentY = topLeft.y + @as(f32, @floatFromInt(lastDisplayLevelWithoutMultPlusOne - firstDisplayLevelWithoutMult + 1)) * vulkanFontSize;
    if (state.statistics.uxData.displayTimeInShop) {
        var shoppingTime = state.statistics.totalShoppingTime;
        if (state.gamePhase == .shopping) {
            if (state.shop.backwardsShopEnterTime) |time| {
                shoppingTime += state.statistics.uxData.currentTimestamp - time;
            } else {
                shoppingTime += state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - currentRunStats[state.level - 1].totalTime;
            }
        }
        const textWidth = fontVulkanZig.paintText("Shop: ", .{
            .x = topLeft.x,
            .y = currentY,
        }, fontSize, textColor, state);
        _ = try fontVulkanZig.paintTime(shoppingTime, .{
            .x = topLeft.x + textWidth,
            .y = currentY,
        }, fontSize, true, textColor, state);
        currentY += vulkanFontSize;
    }
    currentY += vulkanFontSize;
    if (state.statistics.uxData.displayBestPossibleTime) {
        if (state.statistics.uxData.displayBestPossibleTimeValue == null) {
            try calculateSumOfGoldsOfRemainingLevels(state);
        }
        var pastTimePart: ?i64 = null;
        if (state.gamePhase == .finished) {
            pastTimePart = currentRunStats[state.level - 1].totalTime;
        } else if (state.gamePhase == .shopping) {
            if (bestRunStats.len > state.level and bestRunStats[state.level].time != null) {
                const lastLevelFinishTime = currentRunStats[state.level - 1].totalTime;
                const currentLevelEstimate = @max(bestRunStats[state.level].time.?, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelFinishTime);
                pastTimePart = lastLevelFinishTime + currentLevelEstimate;
            }
        } else if (state.level == 1) {
            if (bestRunStats[0].time) |fastestTime| {
                pastTimePart = @max(fastestTime, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime);
            }
        } else {
            if (bestRunStats.len >= state.level and bestRunStats[state.level - 1].time != null) {
                const fastestTime = bestRunStats[state.level - 1].time.?;
                const lastLevelFinishTime = currentRunStats[state.level - 2].totalTime;
                const currentLevelEstimate = @max(fastestTime, state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - lastLevelFinishTime);
                pastTimePart = lastLevelFinishTime + currentLevelEstimate;
            }
        }
        if (pastTimePart) |timePart| {
            try displayTextNumberTextTime(
                "Best Possible Time: Level ",
                state.statistics.uxData.displayBestPossibleTimeLevel,
                " in ",
                state.statistics.uxData.displayBestPossibleTimeValue.? + timePart,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += vulkanFontSize;
        }
    }
    if (state.statistics.uxData.displayBestRun) {
        var furthestDataIndex: usize = 0;
        for (bestRunStats, 0..) |level, index| {
            if (level.totalTime != null) {
                furthestDataIndex = index;
            }
        }
        if (bestRunStats[furthestDataIndex].totalTime) |fastestTotalTime| {
            try displayTextNumberTextTime(
                "Best Run: Level ",
                furthestDataIndex + 1,
                " in ",
                fastestTotalTime,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += vulkanFontSize;
        }
    }
    if (state.statistics.uxData.displayGoldRun) {
        if (state.statistics.uxData.displayGoldRunValue == null) {
            try calculateSumOfGolds(state);
        }
        if (state.statistics.uxData.displayGoldRunValue) |goldRunTime| {
            try displayTextNumberTextTime(
                "Gold Run: Level ",
                state.statistics.uxData.displayGoldRunLevel,
                " in ",
                goldRunTime,
                .{ .x = topLeft.x, .y = currentY },
                fontSize,
                textColor,
                state,
            );
            currentY += vulkanFontSize;
        }
    }
}

fn displayTextNumberTextTime(text1: []const u8, number: anytype, text2: []const u8, time: i64, topLeft: main.Position, fontSize: f32, textColor: [4]f32, state: *main.GameState) !void {
    var textWidth: f32 = 0;
    textWidth += fontVulkanZig.paintText(text1, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, state);
    textWidth += try fontVulkanZig.paintNumber(number, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, state);
    textWidth += fontVulkanZig.paintText(text2, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, textColor, state);
    _ = try fontVulkanZig.paintTime(time, .{
        .x = topLeft.x + textWidth,
        .y = topLeft.y,
    }, fontSize, true, textColor, state);
}

fn setupVerticesLevel(level: u32, bestRunStats: []BestLevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    _ = bestRunStats;
    const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level + 4, 5) * 5 else state.level;
    const alpha: f32 = if (level > currentDisplayLevelOfPlayer) 0.5 else 1;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    const textWidth = fontVulkanZig.getTextVulkanWidth(columnData.name, state.statistics.uxData.fontSize, state);
    _ = try fontVulkanZig.paintNumber(level, .{
        .x = paintPos.x + columnWidth - textWidth,
        .y = paintPos.y,
    }, state.statistics.uxData.fontSize, .{ 1, 1, 1, alpha }, state);
}

fn setupVerticesTime(level: u32, bestRunStats: []BestLevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level + 4, 5) * 5 else state.level;
    const alpha: f32 = if (level > currentDisplayLevelOfPlayer) 0.5 else 1;
    const textColor: [4]f32 = .{ 1, 1, 1, alpha };
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    const currentLevelData = state.statistics.currentRunStats.levelDatas.items;
    var displayTime: i64 = if (currentLevelData.len >= level) currentLevelData[level - 1].totalTime else 0;
    if (state.statistics.uxData.groupingLevelsInFive and @divFloor(level, 5) == @divFloor(state.level + 4, 5) and ((state.gamePhase != .shopping and state.gamePhase != .finished) or @mod(state.level, 5) != 0)) {
        displayTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
    } else if (level == state.level and state.gamePhase != .shopping and state.gamePhase != .finished) {
        displayTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
    } else if (level > state.level) {
        if (bestRunStats.len >= level and bestRunStats[level - 1].totalTime != null) {
            displayTime = bestRunStats[level - 1].totalTime.?;
        } else {
            const textWidht = fontVulkanZig.getTextVulkanWidth("--", state.statistics.uxData.fontSize, state);
            const paintX = paintPos.x + columnWidth - textWidht;
            _ = fontVulkanZig.paintText("--", .{ .x = paintX, .y = paintPos.y }, state.statistics.uxData.fontSize, textColor, state);
            return;
        }
    }
    const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(displayTime, state.statistics.uxData.fontSize, true, state);
    const paintX = paintPos.x + columnWidth - textWidht;
    _ = try fontVulkanZig.paintTime(displayTime, .{ .x = paintX, .y = paintPos.y }, state.statistics.uxData.fontSize, true, textColor, state);
}

fn setupVerticesLevelDiff(level: u32, bestRunStats: []BestLevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    if (level - 1 >= bestRunStats.len) return;
    const bestLevelData = bestRunStats[level - 1];
    if (bestLevelData.time) |levelFastestTime| {
        var fastestTime = levelFastestTime;
        if (state.statistics.uxData.groupingLevelsInFive) {
            for (1..5) |i| {
                fastestTime += bestRunStats[level - i - 1].time.?;
            }
        }
        const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
        const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const fontSize = state.statistics.uxData.fontSize;
        const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level - 1, 5) * 5 + 5 else state.level;
        if (level > currentDisplayLevelOfPlayer) {
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(fastestTime, fontSize, true, state);
            const paintX = paintPos.x + columnWidth - textWidht;
            _ = try fontVulkanZig.paintTime(fastestTime, .{ .x = paintX, .y = paintPos.y }, fontSize, true, .{ 1, 1, 1, 0.5 }, state);
        } else {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var levelCurrentTime: i64 = 0;
            if (state.statistics.uxData.groupingLevelsInFive) {
                if (currentDisplayLevelOfPlayer == level) {
                    if (state.level == 1) {
                        if (state.gamePhase != .shopping) {
                            levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
                        } else {
                            levelCurrentTime = state.statistics.currentRunStats.levelDatas.items[0].time;
                        }
                    } else {
                        const levelItCount = @mod(state.level - 1, 5);
                        levelCurrentTime = 0;
                        for (0..levelItCount) |i| {
                            levelCurrentTime += state.statistics.currentRunStats.levelDatas.items[level - (4 - i) - 1].time;
                        }
                        if (state.gamePhase != .shopping and state.gamePhase != .finished) {
                            const currentLastLevelData = &state.statistics.currentRunStats.levelDatas.items[state.level - 2];
                            levelCurrentTime += state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - currentLastLevelData.totalTime - currentLastLevelData.shoppingTime;
                        } else {
                            levelCurrentTime += state.statistics.currentRunStats.levelDatas.items[state.level - 1].time;
                        }
                    }
                } else {
                    for (0..5) |i| {
                        levelCurrentTime += state.statistics.currentRunStats.levelDatas.items[level - i - 1].time;
                    }
                }
            } else if (level == state.level and state.gamePhase != .shopping and state.gamePhase != .finished) {
                if (level > 1) {
                    const currentLastLevelData = &state.statistics.currentRunStats.levelDatas.items[level - 2];
                    levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - currentLastLevelData.totalTime - currentLastLevelData.shoppingTime;
                } else {
                    levelCurrentTime = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime;
                }
            } else {
                levelCurrentTime = state.statistics.currentRunStats.levelDatas.items[level - 1].time;
            }
            const diff = levelCurrentTime - fastestTime;
            const color = if (diff > 0) red else green;
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(diff, fontSize, true, state);
            if (diff > 0) {
                const textPlusWidht = fontVulkanZig.getTextVulkanWidth("+", fontSize, state);
                const paintX = paintPos.x + columnWidth - textWidht - textPlusWidht;
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintX, .y = paintPos.y }, fontSize, color, state);
                _ = try fontVulkanZig.paintTime(diff, .{ .x = paintX + plusWidth, .y = paintPos.y }, fontSize, true, color, state);
            } else {
                const paintX = paintPos.x + columnWidth - textWidht;
                _ = try fontVulkanZig.paintTime(diff, .{ .x = paintX, .y = paintPos.y }, fontSize, true, color, state);
            }
        }
    }
}

fn setupVerticesTotalDiff(level: u32, bestRunStats: []BestLevelStatistics, paintPos: main.Position, columnData: ColumnData, state: *main.GameState) anyerror!void {
    if (level - 1 >= bestRunStats.len) return;
    const bestLevelData = bestRunStats[level - 1];
    if (bestLevelData.totalTime) |fastestTime| {
        const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
        const columnWidth = columnData.pixelWidth * onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
        const fontSize = state.statistics.uxData.fontSize;
        const currentDisplayLevelOfPlayer = if (state.statistics.uxData.groupingLevelsInFive) @divFloor(state.level - 1, 5) * 5 + 5 else state.level;
        if (level <= currentDisplayLevelOfPlayer) {
            const red: [4]f32 = .{ 0.7, 0, 0, 1 };
            const green: [4]f32 = .{ 0.1, 1, 0.1, 1 };
            var diffTotal: i64 = 0;
            if (level > state.level or (level == state.level and state.gamePhase != .shopping and state.gamePhase != .finished)) {
                diffTotal = state.statistics.uxData.currentTimestamp - state.statistics.runStartedTime - fastestTime;
            } else {
                diffTotal = state.statistics.currentRunStats.levelDatas.items[level - 1].totalTime - fastestTime;
            }

            const color: [4]f32 = if (diffTotal > 0) red else green;
            const textWidht = try fontVulkanZig.getTimeTextVulkanWidth(diffTotal, fontSize, true, state);
            if (diffTotal > 0) {
                const textPlusWidht = fontVulkanZig.getTextVulkanWidth("+", fontSize, state);
                const paintX = paintPos.x + columnWidth - textWidht - textPlusWidht;
                const plusWidth = fontVulkanZig.paintText("+", .{ .x = paintX, .y = paintPos.y }, fontSize, color, state);
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintX + plusWidth, .y = paintPos.y }, fontSize, true, color, state);
            } else {
                const paintX = paintPos.x + columnWidth - textWidht;
                _ = try fontVulkanZig.paintTime(diffTotal, .{ .x = paintX, .y = paintPos.y }, fontSize, true, color, state);
            }
        }
    }
}

pub fn getBestRunStats(state: *main.GameState) ![]BestLevelStatistics {
    var optLevelDatas: ?*std.ArrayList(BestLevelStatistics) = null;
    const playerCount = state.statistics.currentRunStats.playerCount;
    const newGamePlus = state.statistics.currentRunStats.newGamePlus;
    for (state.statistics.bestRunStats.items) |*levelDataForPlayerCount| {
        if (playerCount == levelDataForPlayerCount.playerCount and newGamePlus == levelDataForPlayerCount.newGamePlus) {
            optLevelDatas = &levelDataForPlayerCount.levelDatas;
        }
    }
    if (optLevelDatas == null) {
        try state.statistics.bestRunStats.append(.{
            .levelDatas = std.ArrayList(BestLevelStatistics).init(state.allocator),
            .playerCount = @intCast(playerCount),
            .newGamePlus = newGamePlus,
        });
        optLevelDatas = &state.statistics.bestRunStats.items[state.statistics.bestRunStats.items.len - 1].levelDatas;
    }
    if (optLevelDatas.?.items.len < state.level) {
        try optLevelDatas.?.append(.{});
    }

    return optLevelDatas.?.items;
}

pub fn loadStatisticsDataFromFile(state: *main.GameState) void {
    const filepath = fileSaveZig.getSavePath(state.allocator, FILE_NAME_STATISTICS_DATA) catch return;
    defer state.allocator.free(filepath);

    loadFromFile(state, filepath) catch {
        //ignore for now
    };
}

fn loadFromFile(state: *main.GameState, filepath: []const u8) !void {
    const file = std.fs.cwd().openFile(filepath, .{}) catch return;
    defer file.close();

    const reader = file.reader();
    const safeFileVersion = try reader.readByte();
    if (safeFileVersion != SAFE_FILE_VERSION) {
        // std.debug.print("not loading outdated save file version");
    }

    const statisticsForPlayerCountLength: usize = try reader.readInt(usize, .little);
    for (0..statisticsForPlayerCountLength) |_| {
        const playerCount = try reader.readInt(u32, .little);
        const newGamePlus = try reader.readInt(u32, .little);
        const levelDataLength: usize = try reader.readInt(usize, .little);
        try state.statistics.bestRunStats.append(.{
            .levelDatas = std.ArrayList(BestLevelStatistics).init(state.allocator),
            .playerCount = playerCount,
            .newGamePlus = newGamePlus,
        });
        const levelDatas = &state.statistics.bestRunStats.items[state.statistics.bestRunStats.items.len - 1];
        for (0..levelDataLength) |levelDataIndex| {
            try levelDatas.levelDatas.append(.{});
            const levelData: *BestLevelStatistics = &levelDatas.levelDatas.items[levelDataIndex];
            levelData.time = try reader.readInt(i64, .little);
            if (levelData.time.? < 0) levelData.time = null;
            levelData.totalTime = try reader.readInt(i64, .little);
            if (levelData.totalTime.? < 0) levelData.totalTime = null;
        }
    }
}

fn saveStatisticsDataToFile(state: *main.GameState) !void {
    const filepath = try fileSaveZig.getSavePath(state.allocator, FILE_NAME_STATISTICS_DATA);
    defer state.allocator.free(filepath);

    const file = try std.fs.cwd().createFile(filepath, .{ .truncate = true });
    defer file.close();

    const writer = file.writer();
    _ = try writer.writeByte(SAFE_FILE_VERSION);
    _ = try writer.writeInt(usize, state.statistics.bestRunStats.items.len, .little);
    for (state.statistics.bestRunStats.items) |statisticsForPlayerCount| {
        _ = try writer.writeInt(u32, statisticsForPlayerCount.playerCount, .little);
        _ = try writer.writeInt(u32, statisticsForPlayerCount.newGamePlus, .little);
        _ = try writer.writeInt(usize, statisticsForPlayerCount.levelDatas.items.len, .little);
        for (statisticsForPlayerCount.levelDatas.items) |levelStatistics| {
            _ = try writer.writeInt(i64, if (levelStatistics.time) |ft| ft else -1, .little);
            _ = try writer.writeInt(i64, if (levelStatistics.totalTime) |ftt| ftt else -1, .little);
        }
    }
}

fn calculateSumOfGolds(state: *main.GameState) !void {
    const levelDatas: []BestLevelStatistics = try getBestRunStats(state);
    var sumOfGold: i64 = 0;
    for (levelDatas, 0..) |level, index| {
        if (level.time) |fastestTime| {
            sumOfGold += fastestTime;
            state.statistics.uxData.displayGoldRunLevel = @intCast(index + 1);
        }
    }
    if (sumOfGold > 0) {
        state.statistics.uxData.displayGoldRunValue = sumOfGold;
    } else {
        state.statistics.uxData.displayGoldRunValue = null;
    }
}

fn calculateSumOfGoldsOfRemainingLevels(state: *main.GameState) !void {
    const levelDatas: []BestLevelStatistics = try getBestRunStats(state);
    var sumOfGoldRemaining: i64 = 0;
    const startLevel = if (state.gamePhase == .shopping) state.level + 1 else state.level;
    if (startLevel < levelDatas.len) {
        for (startLevel..levelDatas.len) |index| {
            const level = levelDatas[index];
            if (level.time) |fastestTime| {
                sumOfGoldRemaining += fastestTime;
                state.statistics.uxData.displayBestPossibleTimeLevel = @intCast(index + 1);
            }
        }
    }
    state.statistics.uxData.displayBestPossibleTimeValue = sumOfGoldRemaining;
}
