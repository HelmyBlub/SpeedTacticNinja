const std = @import("std");
const main = @import("main.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const shopZig = @import("shop.zig");
const choosenMovePieceVisualizationVulkanZig = @import("vulkan/choosenMovePieceVisualizationVulkan.zig");
const bossZig = @import("boss/boss.zig");
const enemyZig = @import("enemy/enemy.zig");
const enemyObjectZig = @import("enemy/enemyObject.zig");
const enemyObjectFallDownZig = @import("enemy/enemyObjectFallDown.zig");
const mapTileZig = @import("mapTile.zig");
const playerZig = @import("player.zig");
const windowSdlZig = @import("windowSdl.zig");
const inputZig = @import("input.zig");

pub const MovePiece = struct {
    steps: []MoveStep,
};

pub const MoveStep = struct {
    direction: u8,
    stepCount: u8,
};

const EnemyMovePieceData = struct {
    pos: *main.Position,
    enemyImageIndex: u8,
};

pub const DIRECTION_RIGHT = 0;
pub const DIRECTION_DOWN = 1;
pub const DIRECTION_LEFT = 2;
pub const DIRECTION_UP = 3;

fn setRandomMovePiece(player: *playerZig.Player, index: usize, state: *main.GameState) !void {
    const rand = &state.seededRandom.random();
    if (player.availableMovePieces.items.len > 0) {
        const randomPieceIndex: usize = @intFromFloat(rand.float(f32) * @as(f32, @floatFromInt(player.availableMovePieces.items.len)));
        const randomPiece = player.availableMovePieces.swapRemove(randomPieceIndex);
        if (player.moveOptions.items.len <= index) {
            try player.moveOptions.append(randomPiece);
        } else {
            player.moveOptions.items[index] = randomPiece;
        }
    } else if (player.moveOptions.items.len > index) {
        _ = player.moveOptions.swapRemove(index);
    }
}

///valid = end of move piece is in grid for returned direction
/// returned null => there is no possible move direction ending up in grid
pub fn getRandomValidMoveDirectionForMovePiece(position: main.Position, movePiece: MovePiece, state: *main.GameState) !?u8 {
    const gridBorderX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * main.TILESIZE);
    const gridBorderY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * main.TILESIZE);
    var direction: u8 = 0;
    var validMovePosition = false;
    var directionOptions = [_]u8{ 0, 1, 2, 3 };
    var directionOptionCount: usize = 4;
    while (!validMovePosition) {
        if (directionOptionCount == 0) return null;
        var bossPositionAfterPiece = position;
        const randomIndex = state.seededRandom.random().intRangeLessThan(usize, 0, directionOptionCount);
        direction = directionOptions[randomIndex];
        directionOptionCount -|= 1;
        directionOptions[randomIndex] = directionOptions[directionOptionCount];
        try movePositionByPiece(&bossPositionAfterPiece, movePiece, direction, state);
        validMovePosition = bossPositionAfterPiece.x >= -gridBorderX and bossPositionAfterPiece.x <= gridBorderX and bossPositionAfterPiece.y >= -gridBorderY and bossPositionAfterPiece.y <= gridBorderY;
    }
    return direction;
}

pub fn setupMovePieces(player: *playerZig.Player, state: *main.GameState) !void {
    var done = false;
    while (!done) {
        if (player.totalMovePieces.items.len > 0) {
            for (player.totalMovePieces.items) |movePiece| {
                state.allocator.free(movePiece.steps);
            }
            player.totalMovePieces.clearRetainingCapacity();
        }
        player.availableMovePieces.clearRetainingCapacity();
        player.moveOptions.clearRetainingCapacity();
        total: while (player.totalMovePieces.items.len < 7) {
            const randomPiece = try createRandomMovePiecePlayer(state.allocator, state);
            for (player.totalMovePieces.items) |otherPiece| {
                if (areSameMovePieces(randomPiece, otherPiece)) {
                    state.allocator.free(randomPiece.steps);
                    continue :total;
                }
            }
            try player.totalMovePieces.append(randomPiece);
        }

        done = validatePlayerMovePiecesToFullfillDemands(player);
    }

    try player.availableMovePieces.appendSlice(player.totalMovePieces.items);
    try setRandomMovePiece(player, 0, state);
    try setRandomMovePiece(player, 1, state);
    try setRandomMovePiece(player, 2, state);
}

pub fn getStepDirection(direction: u8) main.Position {
    switch (direction) {
        DIRECTION_RIGHT => {
            return .{ .x = 1, .y = 0 };
        },
        DIRECTION_DOWN => {
            return .{ .x = 0, .y = 1 };
        },
        DIRECTION_LEFT => {
            return .{ .x = -1, .y = 0 };
        },
        else => {
            return .{ .x = 0, .y = -1 };
        },
    }
}
pub fn getStepDirectionTile(direction: u8) main.TilePosition {
    switch (direction) {
        DIRECTION_RIGHT => {
            return .{ .x = 1, .y = 0 };
        },
        DIRECTION_DOWN => {
            return .{ .x = 0, .y = 1 };
        },
        DIRECTION_LEFT => {
            return .{ .x = -1, .y = 0 };
        },
        else => {
            return .{ .x = 0, .y = -1 };
        },
    }
}

pub fn getMovePieceTotalStepes(movePiece: MovePiece) usize {
    var total: usize = 0;
    for (movePiece.steps) |step| {
        total += step.stepCount;
    }
    return total;
}

pub fn setMoveOptionIndex(player: *playerZig.Player, index: usize, state: *main.GameState) void {
    if (state.gameOver and state.timeFreezed != null and state.timeFreezed.? >= 1500) state.timeFreezed = null;
    if (player.moveOptions.items.len > index) {
        if (state.tutorialData.active and state.tutorialData.playerFirstValidPieceSelection == null) {
            state.tutorialData.playerFirstValidPieceSelection = std.time.milliTimestamp();
        }
        player.choosenMoveOptionIndex = index;
        if (player.equipment.hasEyePatch) player.choosenMoveOptionIndex = 0;
        ninjaDogVulkanZig.swordHandsCentered(player, state);
        player.choosenMoveOptionVisualizationOverlapping = choosenMovePieceVisualizationVulkanZig.isChoosenPieceVisualizationOverlapping(player.moveOptions.items[player.choosenMoveOptionIndex.?]);
    }
}

pub fn tickPlayerMovePiece(player: *playerZig.Player, state: *main.GameState) !void {
    if (player.executeMovePiece) |executeMovePiece| {
        const step = executeMovePiece.steps[0];
        const direction = @mod(step.direction + player.executeDirection + 1, 4);
        if (!player.slashedLastMoveTile) ninjaDogVulkanZig.movedAnimate(player, direction, state);
        try stepAndCheckEnemyHitAndProjectileHitAndTiles(player, step.stepCount, direction, getStepDirection(direction), state);
        if (executeMovePiece.steps.len > 1) {
            player.executeMovePiece = .{ .steps = executeMovePiece.steps[1..] };
        } else {
            player.executeMovePiece = null;
            if (state.mapData.mapType == .top and state.gamePhase != .finished) {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (@abs(playerTile.x) > state.mapData.tileRadiusWidth or @abs(playerTile.y) > state.mapData.tileRadiusHeight) {
                    if (player.startedFallingState == null) player.startedFallingState = state.gameTime;
                    player.animateData.ears.leftVelocity = 5;
                    player.animateData.ears.rightVelocity = 5;
                } else {
                    player.startedFallingState = null;
                }
            }
            if (player.moveOptions.items.len == 0) {
                try enemyObjectFallDownZig.spawnFallDown(player.position, 2000, true, state);
            } else if (player.moveOptions.items.len == 2 and state.gamePhase != .shopping and state.gamePhase != .finished and state.gamePhase != .modeSelect) {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_MOVE_PIECE_WARNING, 0, 1);
            }
        }
        if (player.executeMovePiece == null) {
            ninjaDogVulkanZig.moveHandToCenter(player, state);
            if (state.gamePhase == .shopping or state.gamePhase == .modeSelect) {
                try inputZig.onPlayerMoveActionFinished(player, state);
            } else if (state.gamePhase == .finished) {
                if (state.uxData.creditsScrollStart == null and shopZig.isPlayerInShopTrigger(player, state)) {
                    try main.runStart(state, state.newGamePlus + 1);
                }
            } else {
                try bossZig.onPlayerMoved(player, state);
                const attackDelayOnSpawn = 100;
                if (state.gameTime - state.roundStartedTime > attackDelayOnSpawn) try enemyZig.onPlayerMoved(player, state);
                if (state.round >= state.config.roundToReachForNextLevel and shopZig.isPlayerInShopTrigger(player, state)) {
                    player.phase = .shopping;
                }
            }
            zoomIfPlayerOutsideOfScreen(player, state);
        }
    }
}

fn zoomIfPlayerOutsideOfScreen(player: *playerZig.Player, state: *main.GameState) void {
    if (state.players.items.len > 1) return;
    if (state.level > 4 or state.round > 4) return;
    if (state.gamePhase == .shopping) return;
    main.adjustZoom(state);
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const playerVulkanPosition: main.Position = .{
        .x = (player.position.x - state.camera.position.x) * state.camera.zoom * onePixelXInVulkan,
        .y = (player.position.y - state.camera.position.y) * state.camera.zoom * onePixelYInVulkan,
    };
    if (@abs(playerVulkanPosition.x) > 1 or @abs(playerVulkanPosition.y) > 1) {
        const changeTo = state.camera.zoom / (@max(@abs(playerVulkanPosition.x), @abs(playerVulkanPosition.y)) + 0.1);
        if (changeTo > 1.5) {
            state.camera.zoom = changeTo;
        } else {
            state.camera.zoom = 1.5;
        }
    }
}

pub fn movePositionByPiece(position: *main.Position, movePiece: MovePiece, executeDirection: u8, state: *main.GameState) !void {
    const startTile = main.gamePositionToTilePosition(position.*);
    try executeMovePieceWithCallbackPerStep(*main.Position, movePiece, executeDirection, startTile, position, movePositionByPieceCallback, state);
}

fn movePositionByPieceCallback(pos: main.TilePosition, visualizationDirection: u8, movePosition: *main.Position, state: *main.GameState) !void {
    _ = visualizationDirection;
    _ = state;
    movePosition.x = @floatFromInt(pos.x * main.TILESIZE);
    movePosition.y = @floatFromInt(pos.y * main.TILESIZE);
}

pub fn attackMovePieceCheckPlayerHit(position: *main.Position, enemyImageIndex: u8, movePiece: MovePiece, executeDirection: u8, state: *main.GameState) !void {
    const startPosition: main.TilePosition = main.gamePositionToTilePosition(position.*);
    try executeMovePieceWithCallbackPerStep(
        EnemyMovePieceData,
        movePiece,
        executeDirection,
        startPosition,
        EnemyMovePieceData{ .pos = position, .enemyImageIndex = enemyImageIndex },
        moveEnemyAndCheckPlayerHitOnMoveStep,
        state,
    );
}

pub fn combineMovePieces(player: *playerZig.Player, movePieceIndex1: usize, movePieceIndex2: usize, combineDirection: u8, state: *main.GameState) !void {
    if (movePieceIndex1 == movePieceIndex2) {
        std.debug.print("can not combine move piece with itself\n", .{});
        return;
    }
    const movePiece1 = player.totalMovePieces.items[movePieceIndex1];
    const movePiece2 = player.totalMovePieces.items[movePieceIndex2];
    const combineLastFirst = movePiece1.steps[movePiece1.steps.len - 1].direction == @mod(movePiece2.steps[0].direction + combineDirection, 4);
    const combinedLength = if (combineLastFirst) movePiece1.steps.len + movePiece2.steps.len - 1 else movePiece1.steps.len + movePiece2.steps.len;
    const newSteps = try state.allocator.alloc(MoveStep, combinedLength);
    const newMovePiece: MovePiece = .{ .steps = newSteps };
    var newPieceIndex: usize = 0;
    for (movePiece1.steps) |*step| {
        newMovePiece.steps[newPieceIndex].direction = step.direction;
        newMovePiece.steps[newPieceIndex].stepCount = step.stepCount;
        newPieceIndex += 1;
    }
    for (movePiece2.steps, 0..) |*step, index| {
        if (combineLastFirst and index == 0) {
            newPieceIndex -= 1;
            newMovePiece.steps[newPieceIndex].stepCount += step.stepCount;
        } else {
            newMovePiece.steps[newPieceIndex].direction = @mod(step.direction + combineDirection, 4);
            newMovePiece.steps[newPieceIndex].stepCount = step.stepCount;
        }
        newPieceIndex += 1;
    }
    replaceMovePiece(movePieceIndex1, newMovePiece, player, state.allocator);
    try removeMovePiece(player, movePieceIndex2, state);
}

pub fn cutTilePositionOnMovePiece(player: *playerZig.Player, cutTile: main.TilePosition, movePieceStartTile: main.TilePosition, totalIndexOfMovePieceToCut: usize, state: *main.GameState) !void {
    const movePiece = player.totalMovePieces.items[totalIndexOfMovePieceToCut];
    var x = movePieceStartTile.x;
    var y = movePieceStartTile.y;
    for (movePiece.steps, 0..) |cutPieceStep, stepIndex| {
        var left = x;
        var top = y;
        var width: i32 = 1;
        var height: i32 = 1;
        switch (cutPieceStep.direction) {
            DIRECTION_RIGHT => {
                width += cutPieceStep.stepCount;
                x += cutPieceStep.stepCount;
            },
            DIRECTION_DOWN => {
                height += cutPieceStep.stepCount;
                y += cutPieceStep.stepCount;
            },
            DIRECTION_LEFT => {
                left -= cutPieceStep.stepCount;
                width += cutPieceStep.stepCount;
                x -= cutPieceStep.stepCount;
            },
            else => {
                top -= cutPieceStep.stepCount;
                height += cutPieceStep.stepCount;
                y -= cutPieceStep.stepCount;
            },
        }
        if (left <= cutTile.x and left + width > cutTile.x and top <= cutTile.y and top + height > cutTile.y) {
            var cutStep = @max(cutTile.x - left, cutTile.y - top);
            if (cutPieceStep.direction == DIRECTION_LEFT) cutStep = width - cutStep - 1;
            if (cutPieceStep.direction == DIRECTION_UP) cutStep = height - cutStep - 1;
            if (cutStep == 0) {
                std.debug.print("should not happen?, movePieceZig cutTilePositionOnMovePiece", .{});
                return;
            }
            const piece1StepCount = if (cutStep > 1) stepIndex + 1 else stepIndex;
            if (piece1StepCount > 0) {
                const steps: []MoveStep = try state.allocator.alloc(MoveStep, piece1StepCount);
                const shortenedPiece: MovePiece = .{ .steps = steps };
                for (steps, 0..) |*splitStep, splitIndex| {
                    splitStep.direction = movePiece.steps[splitIndex].direction;
                    if (cutStep > 1 and piece1StepCount - 1 == splitIndex) {
                        splitStep.stepCount = @intCast(cutStep - 1);
                    } else {
                        splitStep.stepCount = movePiece.steps[splitIndex].stepCount;
                    }
                }
                replaceMovePiece(totalIndexOfMovePieceToCut, shortenedPiece, player, state.allocator);
            }
            return;
        }
    }
}

pub fn isTilePositionOnMovePiece(checkTile: main.TilePosition, movePieceStartTile: main.TilePosition, movePiece: MovePiece, excludeStartPosition: bool) bool {
    var x = movePieceStartTile.x;
    var y = movePieceStartTile.y;
    for (movePiece.steps, 0..) |step, index| {
        var left = x;
        var top = y;
        var width: i32 = 1;
        var height: i32 = 1;
        switch (step.direction) {
            DIRECTION_RIGHT => {
                width = step.stepCount;
                left += 1;
                x += step.stepCount;
                if (index == 0 and excludeStartPosition) {
                    left += 1;
                    width -= 1;
                }
            },
            DIRECTION_DOWN => {
                height = step.stepCount;
                top += 1;
                y += step.stepCount;
                if (index == 0 and excludeStartPosition) {
                    top += 1;
                    height -= 1;
                }
            },
            DIRECTION_LEFT => {
                left -= step.stepCount;
                width = step.stepCount;
                x -= step.stepCount;
                if (index == 0 and excludeStartPosition) {
                    width -= 1;
                }
            },
            else => {
                top -= step.stepCount;
                height = step.stepCount;
                y -= step.stepCount;
                if (index == 0 and excludeStartPosition) {
                    height -= 1;
                }
            },
        }
        if (left <= checkTile.x and left + width > checkTile.x and top <= checkTile.y and top + height > checkTile.y) {
            return true;
        }
    }
    return false;
}

fn stepAndCheckEnemyHitAndProjectileHitAndTiles(player: *playerZig.Player, stepCount: u8, direction: u8, stepDirection: main.Position, state: *main.GameState) !void {
    var currIndex: usize = 0;
    while (currIndex < stepCount) {
        player.slashedLastMoveTile = false;
        try ninjaDogVulkanZig.addAfterImages(1, stepDirection, player, state);
        const movedPosition: main.Position = .{
            .x = player.position.x + stepDirection.x * main.TILESIZE,
            .y = player.position.y + stepDirection.y * main.TILESIZE,
        };
        const tilePosition = main.gamePositionToTilePosition(movedPosition);
        const tileType = mapTileZig.getMapTilePositionType(tilePosition, &state.mapData);
        if (tileType != .wall) {
            player.position = movedPosition;
            var somethingHit = false;
            if (state.modeSelect.selectedMode == .pvp) {
                player.modeData.pvp.lastMoveTime = state.gameTime;
                for (state.players.items) |*otherPlayer| {
                    if (player == otherPlayer) continue;
                    const hitArea: main.TileRectangle = .{ .pos = tilePosition, .height = 1, .width = 1 };
                    const tileOtherPlayer = main.gamePositionToTilePosition(otherPlayer.position);
                    if (main.isTilePositionInTileRectangle(tileOtherPlayer, hitArea)) {
                        try playerZig.playerHit(otherPlayer, state);
                        somethingHit = true;
                    }
                }
            } else {
                somethingHit = try checkEnemyHitOnMoveStep(player, direction, state);
            }
            if (somethingHit) {
                ninjaDogVulkanZig.bladeSlashAnimate(player);
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BLADE_CUT_INDICIES[0..], currIndex * 25, 1);
                try resetPieces(player, true, state);
                player.slashedLastMoveTile = true;
            }
            try bossZig.onPlayerMoveEachTile(player, state);
            try enemyZig.onPlayerMoveEachTile(player, state);
            if (enemyObjectZig.checkHitMovingPlayer(player, state)) {
                try playerZig.playerHit(player, state);
            }
            currIndex += 1;
            if (currIndex == stepCount and tileType == .ice) {
                currIndex -= 1;
            }
        }
        if (player.equipment.hasWeaponKunai and (currIndex == stepCount or tileType == .wall)) {
            const playerTilePosition = main.gamePositionToTilePosition(player.position);
            const tileDirection = getStepDirectionTile(direction);
            var hitArea: main.TileRectangle = .{
                .pos = .{
                    .x = playerTilePosition.x + tileDirection.x,
                    .y = playerTilePosition.y + tileDirection.y,
                },
                .width = @as(i32, @intCast(@abs(tileDirection.x))) + 1,
                .height = @as(i32, @intCast(@abs(tileDirection.y))) + 1,
            };
            if (tileDirection.x < 0) hitArea.pos.x -= 1;
            if (tileDirection.y < 0) hitArea.pos.y -= 1;
            if (try checkEnemyHitOnMoveStepWithHitArea(player, direction, hitArea, state)) {
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_KUNAI_INDICIES[0..], currIndex * 25, 1);
                try state.mapObjects.append(.{ .position = player.position, .typeData = .{ .kunai = .{
                    .direction = direction,
                    .deleteTime = state.gameTime + 200,
                    .speed = 25,
                } } });
                try resetPieces(player, true, state);
            }
        }
        if (player.equipment.hasWeaponHammer and (currIndex == stepCount or tileType == .wall) and player.executeMovePiece.?.steps.len == 1) {
            const playerTilePosition = main.gamePositionToTilePosition(player.position);
            const hammerPositionOffsets = [_]main.TilePosition{
                .{ .x = -1, .y = -1 },
                .{ .x = 0, .y = -1 },
                .{ .x = 1, .y = -1 },
                .{ .x = -1, .y = 0 },
                .{ .x = 1, .y = 0 },
                .{ .x = -1, .y = 1 },
                .{ .x = 0, .y = 1 },
                .{ .x = 1, .y = 1 },
            };
            var hitSomethingWithHammer = false;
            const tileStepDirection = getStepDirectionTile(direction);
            for (0..hammerPositionOffsets.len) |i| {
                const offset = hammerPositionOffsets[i];
                if (offset.x == -tileStepDirection.x and offset.y == -tileStepDirection.y) continue;
                const hitArea: main.TileRectangle = .{ .pos = .{ .x = playerTilePosition.x + offset.x, .y = playerTilePosition.y + offset.y }, .height = 1, .width = 1 };
                var hammerHitDirection = direction;
                if (tileStepDirection.x != 0) {
                    if (tileStepDirection.x != offset.x) {
                        if (offset.y > 0) {
                            hammerHitDirection = DIRECTION_DOWN;
                        } else {
                            hammerHitDirection = DIRECTION_UP;
                        }
                    }
                } else {
                    if (tileStepDirection.y != offset.y) {
                        if (offset.x > 0) {
                            hammerHitDirection = DIRECTION_RIGHT;
                        } else {
                            hammerHitDirection = DIRECTION_LEFT;
                        }
                    }
                }
                if (try checkEnemyHitOnMoveStepWithHitArea(player, hammerHitDirection, hitArea, state)) {
                    hitSomethingWithHammer = true;
                }
            }
            if (hitSomethingWithHammer) {
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_HAMMER_INDICIES[0..], currIndex * 25, 1);
                try resetPieces(player, true, state);
            }
        }
        if (tileType == .wall) return;
    }
}

pub fn executeMovePieceWithCallbackPerStep(
    comptime Data: type,
    movePiece: MovePiece,
    executeDirection: u8,
    startPosition: main.TilePosition,
    context: Data,
    stepFunction: fn (pos: main.TilePosition, visualizedDirection: u8, context: Data, state: *main.GameState) anyerror!void,
    state: *main.GameState,
) !void {
    var curTilePos = startPosition;
    main: for (movePiece.steps, 0..) |step, stepIndex| {
        const currDirection = @mod(step.direction + executeDirection + 1, 4);
        const stepDirection = getStepDirectionTile(currDirection);
        var stepCountIndex: usize = 0;
        while (stepCountIndex < step.stepCount) {
            const movedPosition: main.TilePosition = .{
                .x = curTilePos.x + stepDirection.x,
                .y = curTilePos.y + stepDirection.y,
            };
            const tileType = mapTileZig.getMapTilePositionType(movedPosition, &state.mapData);
            if (tileType == .wall) continue :main;
            curTilePos = movedPosition;
            var visualizedDirection = currDirection;
            if (stepCountIndex == step.stepCount - 1 and movePiece.steps.len > stepIndex + 1) {
                visualizedDirection = @mod(movePiece.steps[stepIndex + 1].direction + executeDirection + 1, 4);
            }
            try stepFunction(curTilePos, visualizedDirection, context, state);
            stepCountIndex += 1;
            if (stepCountIndex == step.stepCount and tileType == .ice) {
                stepCountIndex -= 1;
            }
        }
    }
}

pub fn movePlayerByMovePiece(player: *playerZig.Player, movePieceIndex: usize, directionInput: u8, state: *main.GameState) !void {
    if (player.executeMovePiece != null) return;
    if (player.isDead) {
        if (state.timeFreezed != null and state.timeFreezed.? >= 1500) state.timeFreezed = null;
        return;
    }
    if (player.equipment.hasPirateLegRight and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(directionInput + 1, 4)) return;
    if (player.equipment.hasRollerblades and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(directionInput + 2, 4)) return;
    if (player.equipment.hasPirateLegLeft and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(directionInput + 3, 4)) return;
    if (state.timeFreezed) |timeFreezed| {
        if (timeFreezed > 1000) {
            state.timeFreezed = null;
        } else {
            return;
        }
    }
    if (!player.equipment.hasEyePatch or state.gamePhase == .shopping) player.choosenMoveOptionIndex = null;
    if (player.phase == .shopping and state.gamePhase == .combat) return;
    if (player.moveOptions.items.len <= movePieceIndex) return;
    if (state.tutorialData.active) {
        state.tutorialData.playerFirstValidMove = true;
    }

    player.executeMovePiece = player.moveOptions.items[movePieceIndex];
    player.executeDirection = directionInput;

    try setRandomMovePiece(player, movePieceIndex, state);
    if (player.equipment.hasEyePatch and player.moveOptions.items.len > 0) {
        const newOption = player.moveOptions.items[0];
        for (0..player.moveOptions.items.len - 1) |index| {
            player.moveOptions.items[index] = player.moveOptions.items[index + 1];
        }
        player.moveOptions.items[player.moveOptions.items.len - 1] = newOption;
    }
    player.lastMoveDirection = directionInput;
    try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_NINJA_MOVE_INDICIES[0..], 0, 1);
    if ((state.gamePhase == .shopping or state.gamePhase == .finished or state.gamePhase == .modeSelect) and player.availableMovePieces.items.len == 0 and player.moveOptions.items.len == 0) {
        try resetPieces(player, true, state);
    }
}

pub fn getBoundingBox(movePiece: MovePiece) main.TileRectangle {
    var top: i32 = 0;
    var left: i32 = 0;
    var bottom: i32 = 0;
    var right: i32 = 0;
    var x: i32 = 0;
    var y: i32 = 0;
    for (movePiece.steps) |step| {
        const stepDirection = getStepDirectionTile(step.direction);
        x += stepDirection.x * step.stepCount;
        y += stepDirection.y * step.stepCount;
        if (x < left) left = x else if (x > right) right = x;
        if (y < top) top = y else if (y > bottom) bottom = y;
    }
    return main.TileRectangle{ .height = bottom - top + 1, .width = right - left + 1, .pos = .{ .x = left, .y = top } };
}

pub fn resetPieces(player: *playerZig.Player, visualizeRefresh: bool, state: *main.GameState) !void {
    player.availableMovePieces.clearRetainingCapacity();
    try player.availableMovePieces.appendSlice(player.totalMovePieces.items);
    for (player.moveOptions.items) |moveOption| {
        for (player.availableMovePieces.items, 0..) |piece, index| {
            if (moveOption.steps.ptr == piece.steps.ptr) {
                _ = player.availableMovePieces.swapRemove(index);
                break;
            }
        }
    }
    while (player.moveOptions.items.len < 3 and player.availableMovePieces.items.len > 0) {
        try setRandomMovePiece(player, 3, state);
    }
    if (visualizeRefresh) player.uxData.piecesRefreshedVisualization = state.gameTime;
}

pub fn areSameMovePieces(movePiece1: MovePiece, movePiece2: MovePiece) bool {
    if (movePiece1.steps.len != movePiece2.steps.len) return false;
    for (movePiece1.steps, movePiece2.steps) |stepA, stepB| {
        if (stepA.direction != stepB.direction) return false;
        if (stepA.stepCount != stepB.stepCount) return false;
    }
    return true;
}

pub fn removeMovePiece(player: *playerZig.Player, movePieceIndex: usize, state: *main.GameState) !void {
    const removedPiece = player.totalMovePieces.orderedRemove(movePieceIndex);
    var removed = false;
    for (player.moveOptions.items, 0..) |option, index| {
        if (removedPiece.steps.ptr == option.steps.ptr) {
            try setRandomMovePiece(player, index, state);
            removed = true;
        }
    }
    if (!removed) {
        for (player.availableMovePieces.items, 0..) |option, index| {
            if (removedPiece.steps.ptr == option.steps.ptr) {
                _ = player.availableMovePieces.swapRemove(index);
                removed = true;
            }
        }
    }
    state.allocator.free(removedPiece.steps);
}

pub fn addMovePiece(player: *playerZig.Player, newMovePiece: MovePiece) !void {
    try player.totalMovePieces.append(newMovePiece);
    if (player.moveOptions.items.len < 3) {
        try player.moveOptions.append(newMovePiece);
    } else {
        try player.availableMovePieces.append(newMovePiece);
    }
}

pub fn replaceMovePiece(totalIndex: usize, newPiece: MovePiece, player: *playerZig.Player, allocator: std.mem.Allocator) void {
    const removedPiece = player.totalMovePieces.items[totalIndex];
    player.totalMovePieces.items[totalIndex] = newPiece;
    for (player.moveOptions.items, 0..) |option, index| {
        if (option.steps.ptr == removedPiece.steps.ptr) {
            player.moveOptions.items[index] = newPiece;
            allocator.free(removedPiece.steps);
            return;
        }
    }
    for (player.availableMovePieces.items, 0..) |option, index| {
        if (option.steps.ptr == removedPiece.steps.ptr) {
            player.availableMovePieces.items[index] = newPiece;
            allocator.free(removedPiece.steps);
            return;
        }
    }
    allocator.free(removedPiece.steps);
}

pub fn createRandomMovePiecePlayer(allocator: std.mem.Allocator, state: *main.GameState) !MovePiece {
    return createRandomMovePieceStepsLength(allocator, state.config.playerMovePieceRandom, state.config.playerMovePieceRandom, state);
}

pub fn createRandomMovePiece(allocator: std.mem.Allocator, state: *main.GameState) !MovePiece {
    return createRandomMovePieceStepsLength(allocator, 3, 3, state);
}

pub fn createRandomMovePieceStepsLength(allocator: std.mem.Allocator, maxSteps: u32, maxStepLength: u32, state: *main.GameState) !MovePiece {
    const stepsLength: usize = @intFromFloat(state.seededRandom.random().float(f32) * @as(f32, @floatFromInt(maxSteps)) + 1);
    const steps: []MoveStep = try allocator.alloc(MoveStep, stepsLength);
    const movePiece: MovePiece = .{ .steps = steps };
    var currDirection: u8 = DIRECTION_UP;
    for (movePiece.steps) |*step| {
        step.direction = currDirection;
        step.stepCount = @as(u8, @intFromFloat(state.seededRandom.random().float(f32) * @as(f32, @floatFromInt(maxStepLength)))) + 1;
        currDirection = @mod(currDirection + (@as(u8, @intFromFloat(state.seededRandom.random().float(f32) * 2.0)) * 2 + 1), 4);
    }
    return movePiece;
}

fn checkEnemyHitOnMoveStep(player: *playerZig.Player, hitDirection: u8, state: *main.GameState) !bool {
    const position: main.Position = player.position;
    const tilePosition = main.gamePositionToTilePosition(position);
    const hitArea: main.TileRectangle = .{ .pos = tilePosition, .height = 1, .width = 1 };
    return try checkEnemyHitOnMoveStepWithHitArea(player, hitDirection, hitArea, state);
}

fn checkEnemyHitOnMoveStepWithHitArea(player: *playerZig.Player, hitDirection: u8, hitArea: main.TileRectangle, state: *main.GameState) !bool {
    const rand = &state.seededRandom.random();
    var hitSomething = false;
    var enemyIndex: usize = 0;
    while (enemyIndex < state.enemyData.enemies.items.len) {
        const enemy = &state.enemyData.enemies.items[enemyIndex];
        if (try enemyZig.isEnemyHit(enemy, hitArea, hitDirection, state)) {
            const deadEnemy = state.enemyData.enemies.swapRemove(enemyIndex);
            const cutAngle = player.paintData.weaponRotation + std.math.pi / 2.0;
            try state.spriteCutAnimations.append(.{ .deathTime = state.gameTime, .position = deadEnemy.position, .cutAngle = cutAngle, .force = rand.float(f32) + 0.2, .colorOrImageIndex = .{ .imageIndex = deadEnemy.imageIndex } });
            hitSomething = true;
        } else {
            enemyIndex += 1;
        }
    }
    if (state.bosses.items.len > 0) {
        if (try bossZig.isBossHit(hitArea, player, hitDirection, state)) {
            hitSomething = true;
        }
    }
    return hitSomething;
}

pub fn moveEnemyAndCheckPlayerHitOnMoveStep(hitPosition: main.TilePosition, visualizedDirection: u8, enemyData: EnemyMovePieceData, state: *main.GameState) !void {
    _ = visualizedDirection;
    for (state.players.items) |*player| {
        const playerTile = main.gamePositionToTilePosition(player.position);
        if (playerTile.x == hitPosition.x and playerTile.y == hitPosition.y) {
            try playerZig.playerHit(player, state);
        }
    }

    enemyData.pos.x = @floatFromInt(hitPosition.x * main.TILESIZE);
    enemyData.pos.y = @floatFromInt(hitPosition.y * main.TILESIZE);
    try state.enemyData.afterImages.append(.{ .position = enemyData.pos.*, .deleteTime = state.gameTime + enemyZig.AFTER_IMAGE_DURATION, .imageIndex = enemyData.enemyImageIndex });
}

pub fn getMovePieceTileDistances(movePiece: MovePiece) [2]i32 {
    var x: i32 = 0;
    var y: i32 = 0;
    for (movePiece.steps) |step| {
        const tileDirection = getStepDirectionTile(step.direction);
        x += tileDirection.x * step.stepCount;
        y += tileDirection.y * step.stepCount;
    }
    return [2]i32{ x, y };
}

fn validatePlayerMovePiecesToFullfillDemands(player: *playerZig.Player) bool {
    return isDistanceDemandFullfilled(player) and validateCanReachEveryTile(player);
}

fn validateCanReachEveryTile(player: *playerZig.Player) bool {
    var evenPiece = false;
    var oddPiece = false;
    for (player.totalMovePieces.items) |movePiece| {
        const distances = getMovePieceTileDistances(movePiece);
        if (@mod(distances[0], 2) == 0) {
            evenPiece = true;
        } else {
            oddPiece = true;
        }
        if (@mod(distances[1], 2) == 0) {
            evenPiece = true;
        } else {
            oddPiece = true;
        }
        if (evenPiece and oddPiece) return true;
    }
    return false;
}

fn isDistanceDemandFullfilled(player: *playerZig.Player) bool {
    const toReachStraightDistance = 16;
    var offsetY: i32 = 0;
    var maxStraightDistance: u32 = 0;
    for (player.totalMovePieces.items) |movePiece| {
        const distances = getMovePieceTileDistances(movePiece);
        if (distances[0] == 0) {
            maxStraightDistance += @abs(distances[1]);
        } else if (distances[1] == 0) {
            maxStraightDistance += @abs(distances[0]);
        } else if (@abs(offsetY) < 5) {
            if (@abs(distances[0]) > @abs(distances[1])) {
                maxStraightDistance += @abs(distances[0]);
                offsetY += distances[1] * std.math.sign(distances[0]);
            } else {
                maxStraightDistance += @abs(distances[1]);
                offsetY += distances[0] * std.math.sign(distances[1]) * -1;
            }
        } else if (offsetY < 0) {
            if (std.math.sign(distances[0]) == std.math.sign(distances[1])) {
                maxStraightDistance += @abs(distances[0]);
                offsetY += @intCast(@abs(distances[1]));
            } else {
                maxStraightDistance += @abs(distances[1]);
                offsetY += @intCast(@abs(distances[0]));
            }
        } else {
            if (std.math.sign(distances[0]) == std.math.sign(distances[1])) {
                maxStraightDistance += @abs(distances[1]);
                offsetY -= @intCast(@abs(distances[0]));
            } else {
                maxStraightDistance += @abs(distances[0]);
                offsetY -= @intCast(@abs(distances[1]));
            }
        }
    }
    return maxStraightDistance >= toReachStraightDistance;
}
