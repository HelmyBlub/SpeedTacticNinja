const std = @import("std");
const main = @import("../main.zig");
const fontVulkanZig = @import("fontVulkan.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const bossZig = @import("../boss/boss.zig");
const inputZig = @import("../input.zig");
const playerZig = @import("../player.zig");
const imageZig = @import("../image.zig");
const statsZig = @import("../stats.zig");
const mapTileZig = @import("../mapTile.zig");

pub fn setupVertices(state: *main.GameState) !void {
    try verticesForBossHpBar(state);
    try verticesForTimer(state);
    try verticesForLevelRoundNewGamePlus(state);
    try verticesForPvP(state);
    try verticesForTimeFreeze(state);
    verticesForBossAcedAndFreeContinue(state);
    try verticesForFinished(state);
    try verticesForGameOverOrPaused(state);
    try verticesForLeaveJoinInfo(state);
    verticsForTutorial(state);
    try verticesForAchievementGained(state);
}

fn verticesForAchievementGained(state: *main.GameState) !void {
    if (state.uxData.achievementGained.items.len == 0) return;
    const initialPosition: main.Position = .{
        .x = 0,
        .y = 1,
    };
    const verticeData = &state.vkState.verticeData;
    const fontSize = 50 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const spacingX = 5 * state.windowData.onePixelXInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    const spacingY = 5 * state.windowData.onePixelYInVulkan * state.uxData.settingsMenuUx.uiSizeDelayed;
    const rectangleHeight = fontSize * state.windowData.onePixelYInVulkan + spacingY * 2;
    const appearDuration = 500;
    const fadeAwayDuration = 1000;
    const totalDuration = 5000;
    var offsetY: f32 = 0;
    var currentIndex = state.uxData.achievementGained.items.len;
    while (currentIndex > 0) {
        currentIndex -= 1;
        const achievementGained = state.uxData.achievementGained.items[currentIndex];
        if (achievementGained.displayStartTime + totalDuration < state.gameTime) {
            _ = state.uxData.achievementGained.orderedRemove(currentIndex);
        } else {
            const currentDuration = state.gameTime - achievementGained.displayStartTime;
            var alpha: f32 = 1;
            if (currentDuration > totalDuration - fadeAwayDuration) {
                const durationLeft = totalDuration - currentDuration;
                alpha = @as(f32, @floatFromInt(durationLeft)) / @as(f32, @floatFromInt(fadeAwayDuration));
            }
            if (offsetY == 0 and currentDuration < appearDuration) {
                const appearPerCent: f32 = @as(f32, @floatFromInt(appearDuration - currentDuration)) / @as(f32, @floatFromInt(appearDuration));
                offsetY -= rectangleHeight * appearPerCent;
            }
            offsetY += rectangleHeight + spacingY;
            const textWidth = fontVulkanZig.getTextVulkanWidth(achievementGained.name, fontSize, state);
            const rectangleWidth = fontSize * state.windowData.onePixelXInVulkan + textWidth + spacingX * 4;
            const displayTopLeft: main.Position = .{
                .x = initialPosition.x - rectangleWidth / 2,
                .y = initialPosition.y - offsetY,
            };
            _ = fontVulkanZig.paintText(achievementGained.name, .{
                .x = displayTopLeft.x + fontSize * state.windowData.onePixelXInVulkan + spacingX * 2,
                .y = displayTopLeft.y + spacingY,
            }, fontSize, .{ 1, 1, 1, alpha }, state);
            if (achievementGained.imageIndex) |imageIndex| {
                paintVulkanZig.verticesForComplexSpriteVulkan(.{
                    .x = displayTopLeft.x + fontSize * state.windowData.onePixelXInVulkan / 2 + spacingX,
                    .y = displayTopLeft.y + rectangleHeight / 2,
                }, imageIndex, fontSize, fontSize, 1, 0, false, false, state);
            }
            if (achievementGained.displayCharOnImage) |displayChar| {
                const displayCharFontSize = fontSize * 0.8;
                const charTextWidth = fontVulkanZig.getTextVulkanWidth(displayChar, displayCharFontSize, state);
                _ = fontVulkanZig.paintText(displayChar, .{
                    .x = displayTopLeft.x + fontSize * state.windowData.onePixelXInVulkan / 2 + spacingX - charTextWidth / 2,
                    .y = displayTopLeft.y + spacingY + fontSize * state.windowData.onePixelYInVulkan / 2 - displayCharFontSize * state.windowData.onePixelYInVulkan / 2,
                }, displayCharFontSize, .{ 1, 1, 1, alpha }, state);
            } else if (achievementGained.displayNewGamePlus > 0) {
                const displayCharFontSize = fontSize * 0.8;
                _ = try fontVulkanZig.paintNumber(achievementGained.displayNewGamePlus, .{
                    .x = displayTopLeft.x + fontSize * state.windowData.onePixelXInVulkan / 2 + spacingX - displayCharFontSize * state.windowData.onePixelXInVulkan / 2,
                    .y = displayTopLeft.y + spacingY + fontSize * state.windowData.onePixelYInVulkan / 2 - displayCharFontSize * state.windowData.onePixelYInVulkan / 2,
                }, displayCharFontSize, .{ 1, 1, 1, alpha }, state);
            }
            paintVulkanZig.verticesForRectangle(displayTopLeft.x, displayTopLeft.y, rectangleWidth, rectangleHeight, .{ 1, 1, 1, alpha }, &verticeData.lines, &verticeData.triangles);
        }
    }
}

fn verticesForFinished(state: *main.GameState) !void {
    if (state.gamePhase != .finished) return;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const fontSize = state.uxData.creditsFontSize;
    var finishTimeOffsetY: f32 = -0.99;
    if (state.uxData.creditsScrollStart) |creditsTime| {
        const scrollOffset: f32 = -@as(f32, @floatFromInt(state.gameTime - creditsTime)) / state.uxData.creditsScrollSpeedSlowdown;
        finishTimeOffsetY = scrollOffset + fontSize * onePixelYInVulkan;
        for (main.CREDITS_TEXTS, 0..) |creditsLine, lineIndex| {
            var textWidth = fontVulkanZig.getTextVulkanWidth(creditsLine, fontSize, state);
            var fittedFontSize = fontSize;
            if (textWidth > 2) {
                const changeFactor = 2 / textWidth;
                fittedFontSize *= changeFactor;
                textWidth *= changeFactor;
            }
            const textPos: main.Position = .{
                .x = 0 - textWidth / 2,
                .y = scrollOffset + @as(f32, @floatFromInt(lineIndex)) * fontSize * onePixelYInVulkan,
            };
            _ = fontVulkanZig.paintText(creditsLine, textPos, fittedFontSize, textColor, state);
        }
    }
    const textPos2: main.Position = .{
        .x = -0.5,
        .y = finishTimeOffsetY,
    };
    const finishTextWidth = fontVulkanZig.paintText("Time:", textPos2, fontSize, textColor, state);
    _ = try fontVulkanZig.paintTime(state.statistics.runFinishedTime, .{
        .x = textPos2.x + finishTextWidth,
        .y = textPos2.y,
    }, fontSize, true, textColor, state);
}

fn verticesForBossAcedAndFreeContinue(state: *main.GameState) void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const fontSize = state.windowData.heightFloat * 0.15;
    if (state.uxData.displayBossAcedUntilTime) |time| {
        if (time > state.gameTime) {
            const text = "Aced Boss";
            const textWidth = fontVulkanZig.getTextVulkanWidth(text, fontSize, state);
            const textPos: main.Position = .{ .x = 0 - textWidth / 2, .y = -fontSize * onePixelYInVulkan };
            _ = fontVulkanZig.paintText(text, textPos, fontSize, textColor, state);
        } else {
            state.uxData.displayBossAcedUntilTime = null;
        }
    }
    if (state.uxData.displayReceivedFreeContinue) |time| {
        if (time > state.gameTime) {
            const text = "+Free Continue";
            const textWidth = fontVulkanZig.getTextVulkanWidth(text, fontSize, state);
            const textPos: main.Position = .{ .x = 0 - textWidth / 2, .y = 0 };
            _ = fontVulkanZig.paintText(text, textPos, fontSize, textColor, state);
        } else {
            state.uxData.displayReceivedFreeContinue = null;
        }
    }
}

fn verticesForBossHpBar(state: *main.GameState) !void {
    if (state.gamePhase == .boss) {
        const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
        const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
        const fontSize = 30 * state.uxData.settingsMenuUx.uiSizeDelayed;
        if (state.bosses.items.len == 0) return;
        const spacingX = onePixelXInVulkan * 5;
        const top = -0.99;
        const height = onePixelYInVulkan * fontSize;
        const length = @as(f32, @floatFromInt(state.bosses.items.len));
        const width: f32 = @min(1, 1.25 / length);
        var currentLeft = -((width * length + spacingX * (length - 1)) / 2);
        for (state.bosses.items) |*boss| {
            try setupVerticesBossHpBar(boss, top, currentLeft, height, width, state);
            currentLeft += width + spacingX;
        }
    }
}

fn verticesForTimeFreeze(state: *main.GameState) !void {
    if (state.timeFreezed == null) return;
    const textColor: [4]f32 = .{ 1, 1, 1, 0.8 };
    const fontSize = state.windowData.heightFloat * 0.15;
    const text = "TIME FREEZE";
    const displayTextWidthEstimate = fontVulkanZig.getTextVulkanWidth(text, fontSize, state);
    const textPosition: main.Position = .{ .x = -displayTextWidthEstimate / 2, .y = -0.99 };
    _ = fontVulkanZig.paintText(text, textPosition, fontSize, textColor, state);
}

fn verticesForGameOverOrPaused(state: *main.GameState) !void {
    if ((state.gameOver or state.paused) and state.timeFreezed == null) {
        const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
        const verticeData = &state.vkState.verticeData;
        const textColor: [4]f32 = .{ 1, 1, 1, 1 };
        const displayText = if (state.gameOver) "Game Over" else "Paused";
        const textSizePerCent = 0.15;
        const fontSize = state.windowData.heightFloat * textSizePerCent;
        const displayTextWidthEstimate = fontVulkanZig.getTextVulkanWidth(displayText, fontSize, state);
        const gameOverPos: main.Position = .{ .x = -displayTextWidthEstimate / 2, .y = -textSizePerCent * 3 };
        _ = fontVulkanZig.paintText(displayText, gameOverPos, fontSize, textColor, state);
        const continueCosts = main.getMoneyCostsForContinue(state);
        const timestamp = std.time.milliTimestamp();
        const optionFontSize = state.windowData.heightFloat * textSizePerCent / 2;
        const optionHeight = optionFontSize * onePixelYInVulkan;
        const spacing = onePixelYInVulkan * 5;
        const black: [4]f32 = .{ 0.0, 0.0, 0.0, 1 };
        const lightGray: [4]f32 = .{ 0.6, 0.6, 0.6, 1 };
        var firstTextWidth: f32 = 0;
        const firstOption: main.Position = .{ .x = gameOverPos.x, .y = gameOverPos.y + fontSize * onePixelYInVulkan };
        var displayFirstOption: bool = true;
        var displayFirstOptionHold: bool = true;
        if (state.gameOver) {
            if (state.level > 1) {
                const hasEnoughMoney = main.hasEnoughMoney(continueCosts, state);
                displayFirstOptionHold = hasEnoughMoney;
                const moneyTextColor: [4]f32 = if (hasEnoughMoney) .{ 0.1, 1, 0.1, 1 } else .{ 0.8, 0, 0, 1 };
                if (hasEnoughMoney) {
                    firstTextWidth += fontVulkanZig.verticesForDisplayButton(firstOption, .pieceSelect1, optionFontSize, &state.players.items[0], state);
                } else {
                    firstTextWidth += state.windowData.onePixelXInVulkan * optionFontSize;
                }
                if (continueCosts > 0) {
                    firstTextWidth += fontVulkanZig.paintText("Continue: $", .{
                        .x = firstOption.x + firstTextWidth,
                        .y = firstOption.y,
                    }, optionFontSize, moneyTextColor, state);
                    firstTextWidth += try fontVulkanZig.paintNumber(continueCosts, .{
                        .x = firstOption.x + firstTextWidth,
                        .y = firstOption.y,
                    }, optionFontSize, moneyTextColor, state);
                } else {
                    firstTextWidth += fontVulkanZig.paintText("Continue: Free(", .{
                        .x = firstOption.x + firstTextWidth,
                        .y = firstOption.y,
                    }, optionFontSize, moneyTextColor, state);
                    if (state.modeSelect.selectedMode == .practice) {
                        firstTextWidth += fontVulkanZig.paintText("Practice", .{
                            .x = firstOption.x + firstTextWidth,
                            .y = firstOption.y,
                        }, optionFontSize, moneyTextColor, state);
                    } else {
                        firstTextWidth += try fontVulkanZig.paintNumber(state.continueData.freeContinues, .{
                            .x = firstOption.x + firstTextWidth,
                            .y = firstOption.y,
                        }, optionFontSize, moneyTextColor, state);
                    }
                    firstTextWidth += fontVulkanZig.paintText(")", .{
                        .x = firstOption.x + firstTextWidth,
                        .y = firstOption.y,
                    }, optionFontSize, moneyTextColor, state);
                }
            } else {
                displayFirstOption = false;
            }
        } else {
            firstTextWidth += fontVulkanZig.verticesForDisplayButton(firstOption, .pieceSelect1, optionFontSize, &state.players.items[0], state);
            firstTextWidth += fontVulkanZig.paintText("Unpause", .{
                .x = firstOption.x + firstTextWidth,
                .y = firstOption.y,
            }, optionFontSize, textColor, state);
        }
        if (displayFirstOption) {
            paintVulkanZig.verticesForRectangle(firstOption.x, firstOption.y, firstTextWidth, optionHeight, black, &verticeData.lines, null);
            if (state.uxData.continueButtonHoldStart != null and displayFirstOptionHold) {
                const time = state.uxData.continueButtonHoldStart.?;
                const fillPerCent = @as(f32, @floatFromInt(timestamp - time)) / @as(f32, @floatFromInt(state.uxData.holdDefaultDuration));
                paintVulkanZig.verticesForRectangle(firstOption.x, firstOption.y, firstTextWidth * fillPerCent, optionHeight, lightGray, null, &verticeData.triangles);
            }
        }
        const restartPos: main.Position = .{ .x = gameOverPos.x, .y = gameOverPos.y + (fontSize + optionFontSize) * onePixelYInVulkan + spacing };
        var restartWidth = fontVulkanZig.verticesForDisplayButton(restartPos, .pieceSelect2, optionFontSize, &state.players.items[0], state);
        restartWidth += fontVulkanZig.paintText("Restart", .{ .x = restartPos.x + restartWidth, .y = restartPos.y }, optionFontSize, textColor, state);
        paintVulkanZig.verticesForRectangle(restartPos.x, restartPos.y, restartWidth, optionHeight, black, &verticeData.lines, null);
        if (state.uxData.restartButtonHoldStart) |time| {
            const fillPerCent = @as(f32, @floatFromInt(timestamp - time)) / @as(f32, @floatFromInt(state.uxData.holdDefaultDuration));
            paintVulkanZig.verticesForRectangle(restartPos.x, restartPos.y, restartWidth * fillPerCent, optionHeight, lightGray, null, &verticeData.triangles);
        }

        const quitPos: main.Position = .{ .x = gameOverPos.x, .y = gameOverPos.y + (fontSize + optionFontSize * 2) * onePixelYInVulkan + spacing * 2 };
        var quitWidth = fontVulkanZig.verticesForDisplayButton(quitPos, .pieceSelect3, optionFontSize, &state.players.items[0], state);
        quitWidth += fontVulkanZig.paintText("Quit", .{ .x = quitPos.x + quitWidth, .y = quitPos.y }, optionFontSize, textColor, state);
        paintVulkanZig.verticesForRectangle(quitPos.x, quitPos.y, quitWidth, optionHeight, black, &verticeData.lines, null);
        if (state.uxData.quitButtonHoldStart) |time| {
            const fillPerCent = @as(f32, @floatFromInt(timestamp - time)) / @as(f32, @floatFromInt(state.uxData.holdDefaultDuration));
            paintVulkanZig.verticesForRectangle(quitPos.x, quitPos.y, quitWidth * fillPerCent, optionHeight, black, null, &verticeData.triangles);
        }
    }
}

fn verticesForTimer(state: *main.GameState) !void {
    const isBossTimer = state.gamePhase == .boss and state.newGamePlus >= 2 and state.level != main.LEVEL_COUNT;
    if (state.round > 1 and state.gamePhase == .combat or isBossTimer) {
        const textColor: [4]f32 = .{ 1, 1, 1, 1 };
        const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
        const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
        const fontSize = state.windowData.heightFloat / 14;
        var timePos: main.Position = .{
            .x = 0,
            .y = -0.99,
        };
        if (isBossTimer) {
            timePos.y += 36 * onePixelYInVulkan;
        }
        paintVulkanZig.verticesForComplexSpriteVulkan(
            .{ .x = timePos.x - fontSize / 2 * onePixelXInVulkan, .y = timePos.y + fontSize / 2 * onePixelYInVulkan },
            imageZig.IMAGE_CLOCK,
            fontSize,
            fontSize,
            1,
            0,
            false,
            false,
            state,
        );
        const remainingTime: i64 = @max(0, @divFloor(state.suddenDeathTimeMs - state.gameTime, 1000));
        var textWidth = try fontVulkanZig.paintNumber(remainingTime, .{ .x = timePos.x, .y = timePos.y }, fontSize, textColor, state);
        if (state.uxData.timeChangeVisualization != null and state.uxData.timeChangeVisualization.? > state.gameTime) {
            if (state.uxData.timeChange == .timeAdded) {
                const addedTimeColor: [4]f32 = .{ 0.1, 1, 0.1, 1 };
                textWidth += fontVulkanZig.paintText(" +", .{ .x = timePos.x + textWidth, .y = timePos.y }, fontSize, addedTimeColor, state);
                _ = try fontVulkanZig.paintNumber(@divFloor(state.uxData.timeChange.timeAdded, 1000), .{ .x = timePos.x + textWidth, .y = timePos.y }, fontSize, addedTimeColor, state);
            } else {
                const rotation: f32 = @as(f32, @floatFromInt(state.gameTime)) / 200;
                paintVulkanZig.verticesForComplexSpriteVulkan(
                    .{ .x = timePos.x + fontSize * onePixelYInVulkan, .y = timePos.y + fontSize / 2 * onePixelYInVulkan },
                    imageZig.IMAGE_ICON_REFRESH,
                    fontSize,
                    fontSize,
                    1,
                    rotation,
                    false,
                    false,
                    state,
                );
            }
        }
    }
}

fn verticesForPvP(state: *main.GameState) !void {
    if (state.modeSelect.selectedMode != .pvp) return;
    if (state.gamePhase == .modeSelect) return;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const white: [4]f32 = .{ 1, 1, 1, 1 };
    const fontSize = 30 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const verticeData = &state.vkState.verticeData;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    var startPos: main.Position = .{
        .x = -0.99,
        .y = -0.99,
    };
    const paddingX = 2 * onePixelXInVulkan;
    const paddingY = 2 * onePixelXInVulkan;
    for (state.players.items, 0..) |*player, index| {
        if (player.modeData != .pvp) continue;
        var textWidth: f32 = 0;
        textWidth += fontVulkanZig.paintText("P", .{ .x = startPos.x + textWidth, .y = startPos.y }, fontSize, textColor, state);
        textWidth += try fontVulkanZig.paintNumber(index + 1, .{ .x = startPos.x + textWidth, .y = startPos.y }, fontSize, textColor, state);
        textWidth += fontVulkanZig.paintText(": ", .{ .x = startPos.x + textWidth, .y = startPos.y }, fontSize, textColor, state);
        textWidth += try fontVulkanZig.paintNumber(player.modeData.pvp.wins, .{ .x = startPos.x + textWidth, .y = startPos.y }, fontSize, textColor, state);
        const playerRec: main.Rectangle = .{
            .pos = .{ .x = startPos.x - paddingX, .y = startPos.y - paddingY },
            .width = textWidth + paddingX * 3,
            .height = fontSize * onePixelYInVulkan + paddingY * 2,
        };
        paintVulkanZig.verticesForRectangle(playerRec.pos.x, playerRec.pos.y, playerRec.width, playerRec.height, white, &verticeData.lines, &verticeData.triangles);
        startPos.x += textWidth + paddingX * 2;
    }
    if (state.gameTime < 2000) {
        if (state.modeSelect.selectedMode.pvp) |playerWonIndex| {
            var textWidth: f32 = 0;
            const winFontSize = fontSize * 2;
            const displayPos: main.Position = .{ .x = -0.2, .y = 0 };
            textWidth += fontVulkanZig.paintText("P", .{ .x = displayPos.x, .y = displayPos.y }, winFontSize, textColor, state);
            textWidth += try fontVulkanZig.paintNumber(playerWonIndex + 1, .{ .x = displayPos.x + textWidth, .y = displayPos.y }, winFontSize, textColor, state);
            textWidth += fontVulkanZig.paintText(" Win", .{ .x = displayPos.x + textWidth, .y = displayPos.y }, winFontSize, textColor, state);
        }
    }
}

fn verticesForLevelRoundNewGamePlus(state: *main.GameState) !void {
    if (state.modeSelect.selectedMode != .newGamePlus and state.modeSelect.selectedMode != .practice and state.modeSelect.selectedMode != .custom) return;
    if (state.gamePhase == .modeSelect) return;
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
    if (state.level > 4) {
        textWidth += fontVulkanZig.paintText("L ", .{ .x = levelPos.x, .y = levelPos.y }, fontSize, textColor, state);
    } else {
        textWidth += fontVulkanZig.paintText("Level ", .{ .x = levelPos.x, .y = levelPos.y }, fontSize, textColor, state);
    }
    textWidth += try fontVulkanZig.paintNumber(state.level, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
    const levelRec: main.Rectangle = .{
        .pos = .{ .x = levelPos.x - paddingX, .y = levelPos.y - paddingY },
        .width = textWidth + paddingX * 3,
        .height = fontSize * onePixelYInVulkan + paddingY * 2,
    };
    state.uxData.levelInfoRec = levelRec;
    paintVulkanZig.verticesForRectangle(levelRec.pos.x, levelRec.pos.y, levelRec.width, levelRec.height, white, &verticeData.lines, &verticeData.triangles);

    if (state.newGamePlus > 0) {
        textWidth += paddingX * 6;
        const newGamePlusStartX = textWidth;
        if (state.level > 4) {
            textWidth += fontVulkanZig.paintText("NG+", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        } else {
            textWidth += fontVulkanZig.paintText("NewGame+ ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        }
        textWidth += try fontVulkanZig.paintNumber(state.newGamePlus, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        const newGamePlusRec: main.Rectangle = .{
            .pos = .{ .x = levelPos.x + newGamePlusStartX - paddingX, .y = levelPos.y - paddingY },
            .width = textWidth - newGamePlusStartX + paddingX * 3,
            .height = fontSize * onePixelYInVulkan + paddingY * 2,
        };
        state.uxData.newGamePlusInfoRec = newGamePlusRec;
        paintVulkanZig.verticesForRectangle(newGamePlusRec.pos.x, newGamePlusRec.pos.y, newGamePlusRec.width, newGamePlusRec.height, white, &verticeData.lines, &verticeData.triangles);
    }

    if (state.gamePhase != .boss and state.gamePhase != .finished and state.round > 0) {
        textWidth += paddingX * 6;
        const roundStartX = textWidth;
        if (state.level > 4) {
            textWidth += fontVulkanZig.paintText("R ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        } else {
            textWidth += fontVulkanZig.paintText("Round ", .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        }
        textWidth += try fontVulkanZig.paintNumber(state.round, .{ .x = levelPos.x + textWidth, .y = levelPos.y }, fontSize, textColor, state);
        const roundRec: main.Rectangle = .{
            .pos = .{ .x = levelPos.x + roundStartX - paddingX, .y = levelPos.y - paddingY },
            .width = textWidth - roundStartX + paddingX * 3,
            .height = fontSize * onePixelYInVulkan + paddingY * 2,
        };
        state.uxData.roundInfoRec = roundRec;
        paintVulkanZig.verticesForRectangle(roundRec.pos.x, roundRec.pos.y, roundRec.width, roundRec.height, white, &verticeData.lines, &verticeData.triangles);
    }
}

///returns true if hovering something
pub fn verticesForHoverInformation(state: *main.GameState) !bool {
    if (main.isPositionInRectangle(state.vulkanMousePosition, state.uxData.levelInfoRec)) {
        fontVulkanZig.verticesForInfoBox(&[_][]const u8{
            "Current Level",
            "Higher level means higher difficulty",
            "Every 5th level is a Boss",
        }, .{ .x = state.uxData.levelInfoRec.pos.x, .y = state.uxData.levelInfoRec.pos.y + state.uxData.levelInfoRec.height }, true, state);
        return true;
    } else if (state.gamePhase != .boss and state.gamePhase != .finished and main.isPositionInRectangle(state.vulkanMousePosition, state.uxData.roundInfoRec)) {
        fontVulkanZig.verticesForInfoBox(&[_][]const u8{
            "Current Round",
            "Round increases when all enemies on screen are destroyed",
            "Finishing a round gives money",
            "Gate opens reaching round 5",
        }, .{ .x = state.uxData.roundInfoRec.pos.x, .y = state.uxData.roundInfoRec.pos.y + state.uxData.roundInfoRec.height }, true, state);
        return true;
    } else if (state.newGamePlus > 0 and main.isPositionInRectangle(state.vulkanMousePosition, state.uxData.newGamePlusInfoRec)) {
        fontVulkanZig.verticesForInfoBox(&[_][]const u8{
            "Higher number higher difficulty increase",
            "NewGame+1 halves enemy action times",
            "NewGame+2 divides enemy action times by 3",
            "NewGame+3 divides enemy action times by 4",
            "and so on",
        }, .{ .x = state.uxData.newGamePlusInfoRec.pos.x, .y = state.uxData.newGamePlusInfoRec.pos.y + state.uxData.newGamePlusInfoRec.height }, true, state);
        return true;
    }
    return false;
}

fn verticsForTutorial(state: *main.GameState) void {
    if (state.paused) return;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    if (state.tutorialData.active and state.tutorialData.firstKeyDownInput != null) {
        if (state.tutorialData.playerFirstValidMove or state.players.items.len > 1) {
            state.tutorialData.active = false;
        } else {
            const realTime = std.time.milliTimestamp();
            const fontSize = 60 * state.uxData.settingsMenuUx.uiSizeDelayed;
            const height = fontSize * onePixelYInVulkan;
            const hintWaitDelay = 10_000;
            if (state.tutorialData.firstKeyDownInput.? + hintWaitDelay < realTime) {
                var textWidth: f32 = 0;
                const left: comptime_float = -0.5;
                const top: f32 = 0 + height / 2;
                const player = &state.players.items[0];
                if (state.tutorialData.playerFirstValidPieceSelection == null) {
                    textWidth += fontVulkanZig.paintText("Press ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect1, fontSize, player, state);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect2, fontSize, player, state);
                    textWidth += fontVulkanZig.paintText("or ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                    textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .pieceSelect3, fontSize, player, state);
                } else if (!state.tutorialData.playerFirstValidMove and state.tutorialData.playerFirstValidPieceSelection.? + hintWaitDelay < realTime) {
                    const inputDevice = inputZig.getPlayerInputDevice(player);
                    if (inputDevice == null or inputDevice.? == .keyboard) {
                        textWidth += fontVulkanZig.paintText("Press ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveUp, fontSize, player, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveLeft, fontSize, player, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveDown, fontSize, player, state);
                        textWidth += fontVulkanZig.paintText("or ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                        textWidth += fontVulkanZig.verticesForDisplayButton(.{ .x = left + textWidth, .y = top }, .moveRight, fontSize, player, state);
                    } else {
                        textWidth += fontVulkanZig.paintText("Use Analog Stick ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                    }
                }
            }
        }
    }
}

fn verticesForLeaveJoinInfo(state: *main.GameState) !void {
    if (state.gamePhase == .boss) return;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    var counter: usize = 0;
    const realTime = std.time.milliTimestamp();
    const fontSize = 60 * state.uxData.settingsMenuUx.uiSizeDelayed;
    const height = fontSize * onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    const displayTextWidthEstimate = fontVulkanZig.getTextVulkanWidth("player x joining", fontSize, state);
    if (state.inputJoinData.inputDeviceDatas.items.len > 0) {
        const textColor: [4]f32 = .{ 0.1, 1, 0.1, 1 };
        const fillColor: [4]f32 = .{ 0.9, 0.9, 0.9, 1 };
        const left: f32 = -displayTextWidthEstimate / 2;
        for (state.inputJoinData.inputDeviceDatas.items) |joinData| {
            if (joinData.pressTime + 1_000 <= realTime) {
                var textWidth: f32 = 0;
                const top: f32 = -0.99 + height * @as(f32, @floatFromInt(counter + 1)) * 1.1;
                textWidth += fontVulkanZig.paintText("Player ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                textWidth += try fontVulkanZig.paintNumber(state.players.items.len + counter + 1, .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
                textWidth += fontVulkanZig.paintText(" joining", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);

                const fillPerCent = @as(f32, @floatFromInt(realTime - joinData.pressTime)) / @as(f32, @floatFromInt(playerZig.PLAYER_JOIN_BUTTON_HOLD_DURATION));
                paintVulkanZig.verticesForRectangle(left, top, textWidth * fillPerCent, height, fillColor, null, &verticeData.triangles);
                paintVulkanZig.verticesForRectangle(left, top, textWidth, height, fillColor, &verticeData.lines, null);
                counter += 1;
            }
        }
    }
    for (state.players.items, 0..) |*player, index| {
        const textColor: [4]f32 = .{ 0.7, 0, 0, 1 };
        const fillColor: [4]f32 = .{ 0.1, 0.1, 0.1, 1 };
        if (player.inputData.holdingKeySinceForLeave != null and player.inputData.holdingKeySinceForLeave.? + 1_000 <= realTime) {
            var textWidth: f32 = 0;
            const left: comptime_float = 0;
            const top: f32 = -0.99 + height * @as(f32, @floatFromInt(counter + 1)) * 1.1;
            textWidth += fontVulkanZig.paintText("Player ", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
            textWidth += try fontVulkanZig.paintNumber(index + 1, .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);
            textWidth += fontVulkanZig.paintText(" leaving", .{ .x = left + textWidth, .y = top }, fontSize, textColor, state);

            const fillPerCent = @as(f32, @floatFromInt(realTime - player.inputData.holdingKeySinceForLeave.?)) / @as(f32, @floatFromInt(playerZig.PLAYER_JOIN_BUTTON_HOLD_DURATION));
            const fillWidth = textWidth * fillPerCent;
            paintVulkanZig.verticesForRectangle(left + textWidth - fillWidth, top, fillWidth, height, fillColor, null, &verticeData.triangles);
            paintVulkanZig.verticesForRectangle(left, top, textWidth, height, fillColor, &verticeData.lines, null);
            counter += 1;
        }
    }
}

fn setupVerticesBossHpBar(boss: *bossZig.Boss, top: f32, left: f32, height: f32, width: f32, state: *main.GameState) !void {
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    const red: [4]f32 = .{ 1, 0, 0, 1 };
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const fontSize = height / onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    var textWidthRound = left;
    textWidthRound += fontVulkanZig.paintText(boss.name, .{ .x = textWidthRound, .y = top }, fontSize, textColor, state) + onePixelXInVulkan * 20;
    textWidthRound += try fontVulkanZig.paintNumber(boss.hp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, state);
    textWidthRound += fontVulkanZig.paintText("/", .{ .x = textWidthRound, .y = top }, fontSize, textColor, state);
    textWidthRound += try fontVulkanZig.paintNumber(boss.maxHp, .{ .x = textWidthRound, .y = top }, fontSize, textColor, state);

    const fillPerCent = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
    paintVulkanZig.verticesForRectangle(left, top, width * fillPerCent, height, red, null, &verticeData.triangles);
    paintVulkanZig.verticesForRectangle(left, top, width, height, red, &verticeData.lines, null);
}
