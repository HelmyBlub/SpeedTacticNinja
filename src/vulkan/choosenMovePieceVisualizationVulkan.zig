const std = @import("std");
const main = @import("../main.zig");
const dataVulkanZig = @import("dataVulkan.zig");
const windowSdlZig = @import("../windowSdl.zig");
const movePieceZig = @import("../movePiece.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const mapTileZig = @import("../mapTile.zig");
const imageZig = @import("../image.zig");
const playerZig = @import("../player.zig");
const equipmentZig = @import("../equipment.zig");

pub fn setupVertices(state: *main.GameState) void {
    const verticeData = &state.vkState.verticeData;
    for (0..state.players.items.len) |index| {
        const startIndex = @mod(@as(usize, @intCast(@divFloor(state.gameTime, 500))), state.players.items.len);
        const player = &state.players.items[@mod(index + startIndex, state.players.items.len)];
        const alpha: f32 = if (0 == index) 1 else 0.5;
        verticesForChoosenMoveOptionVisualization(player, &verticeData.lines, &verticeData.triangles, alpha, state);
    }
}

fn verticesForChoosenMoveOptionVisualization(player: *playerZig.Player, lines: *dataVulkanZig.VkColoredVertexes, triangles: *dataVulkanZig.VkColoredVertexes, alpha: f32, state: *main.GameState) void {
    if (player.equipment.hasBlindfold) return;
    if (player.isDead) return;
    if (player.phase == .shopping and state.gamePhase == .combat) return;
    if (player.choosenMoveOptionIndex == null or player.moveOptions.items.len == 0) return;

    const index = player.choosenMoveOptionIndex.?;
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const zoomedTileSize = main.TILESIZE * state.camera.zoom;
    const baseWidth = zoomedTileSize * onePixelXInVulkan;
    const baseHeight = zoomedTileSize * onePixelYInVulkan;
    const movePiece = player.moveOptions.items[index];
    const pieceTotalSteps = movePieceZig.getMovePieceTotalStepes(movePiece);
    const highlightModLimit = @max(5, pieceTotalSteps + 1);
    for (0..4) |direction| {
        if (player.equipment.hasPirateLegRight and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(direction, 4)) continue;
        if (player.equipment.hasRollerblades and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(direction + 1, 4)) continue;
        if (player.equipment.hasPirateLegLeft and player.lastMoveDirection != null and player.lastMoveDirection.? == @mod(direction + 2, 4)) continue;
        var gamePositionWithCameraOffset: main.Position = .{
            .x = player.position.x - state.camera.position.x,
            .y = player.position.y - state.camera.position.y,
        };

        var lineColorForDirection: [4]f32 = player.uxData.visualizeChoosenMovePieceColor;
        if (state.players.items.len == 1) {
            lineColorForDirection = .{
                if (direction == 0) 0.8 else 0,
                if (direction == 1) 0.2 else 0,
                if (direction == 2) 0.5 else 0,
                1,
            };
        } else {
            lineColorForDirection[3] = alpha;
        }
        const lineColorForDirectionAlpha1: [4]f32 = .{ lineColorForDirection[0], lineColorForDirection[1], lineColorForDirection[2], 1 };
        const highlightedLineColor: [4]f32 = .{ 1, 1, 1, 1 };

        var lastGamePosition: main.Position = gamePositionWithCameraOffset;
        var lastMoveDirection: usize = 0;
        var moveDirection: u8 = 0;
        var totalStepCount: usize = 0;
        for (movePiece.steps, 0..) |moveStep, moveStepIndex| {
            lastMoveDirection = moveDirection;
            moveDirection = @mod(moveStep.direction + @as(u8, @intCast(direction)), 4);
            const moveX: f32 = if (moveDirection == 0) main.TILESIZE else if (moveDirection == 2) -main.TILESIZE else 0;
            const moveY: f32 = if (moveDirection == 1) main.TILESIZE else if (moveDirection == 3) -main.TILESIZE else 0;
            var stepCount: usize = 0;
            while (stepCount < moveStep.stepCount) {
                totalStepCount += 1;
                const modColor = player.choosenMoveOptionVisualizationOverlapping and @mod(totalStepCount, highlightModLimit) == @mod(@as(usize, @intCast(@divFloor(state.gameTime, 100))), highlightModLimit);
                const lineColor = if (modColor) highlightedLineColor else lineColorForDirection;
                lastGamePosition = gamePositionWithCameraOffset;
                const nextPosition: main.Position = .{
                    .x = gamePositionWithCameraOffset.x + moveX,
                    .y = gamePositionWithCameraOffset.y + moveY,
                };
                if (stepCount + 1 < moveStep.stepCount) {
                    const afterNextPosition: main.Position = .{
                        .x = nextPosition.x + moveX,
                        .y = nextPosition.y + moveY,
                    };
                    const afterTilePosition = main.gamePositionToTilePosition(afterNextPosition);
                    const afterTileType = mapTileZig.getMapTilePositionType(afterTilePosition, &state.mapData);
                    if (afterTileType == .wall) {
                        stepCount = moveStep.stepCount - 1;
                    }
                }
                const tilePosition = main.gamePositionToTilePosition(nextPosition);
                const tileType = mapTileZig.getMapTilePositionType(tilePosition, &state.mapData);
                if (tileType != .wall) {
                    gamePositionWithCameraOffset = nextPosition;
                }
                var x = gamePositionWithCameraOffset.x * onePixelXInVulkan * state.camera.zoom;
                var y = gamePositionWithCameraOffset.y * onePixelYInVulkan * state.camera.zoom;
                stepCount += 1;
                if (stepCount == moveStep.stepCount and tileType == .ice) {
                    stepCount -= 1;
                }
                if (stepCount == moveStep.stepCount) {
                    if (moveStepIndex == movePiece.steps.len - 1) {
                        verticesForSquare(x, y, baseWidth, baseHeight, lineColor, lines);
                        verticesForFilledArrow(x, y, baseWidth * 0.9, baseHeight * 0.9, @intCast(@mod(direction + 3, 4)), lineColorForDirectionAlpha1, lines, triangles);
                    } else {
                        const nextDirection = @mod(movePiece.steps[moveStepIndex + 1].direction + direction, 4);
                        var rotation: f32 = 0;
                        const offsetAngledX = baseWidth / 4.0;
                        const offsetAngledY = baseHeight / 4.0;
                        switch (moveDirection) {
                            movePieceZig.DIRECTION_UP => {
                                if (nextDirection == movePieceZig.DIRECTION_LEFT) {
                                    rotation = std.math.pi * 1.25;
                                    x -= offsetAngledX;
                                    y += offsetAngledY;
                                } else {
                                    rotation = std.math.pi * 1.75;
                                    x += offsetAngledX;
                                    y += offsetAngledY;
                                }
                            },
                            movePieceZig.DIRECTION_DOWN => {
                                if (nextDirection == movePieceZig.DIRECTION_LEFT) {
                                    rotation = std.math.pi * 0.75;
                                    x -= offsetAngledX;
                                    y -= offsetAngledY;
                                } else {
                                    rotation = std.math.pi * 0.25;
                                    x += offsetAngledX;
                                    y -= offsetAngledY;
                                }
                            },
                            movePieceZig.DIRECTION_LEFT => {
                                if (nextDirection == movePieceZig.DIRECTION_UP) {
                                    rotation = std.math.pi * 1.25;
                                    x += offsetAngledX;
                                    y -= offsetAngledY;
                                } else {
                                    x += offsetAngledX;
                                    y += offsetAngledY;
                                    rotation = std.math.pi * 0.75;
                                }
                            },
                            else => {
                                if (nextDirection == movePieceZig.DIRECTION_UP) {
                                    rotation = std.math.pi * -0.25;
                                    x -= offsetAngledX;
                                    y -= offsetAngledY;
                                } else {
                                    rotation = std.math.pi * 0.25;
                                    x -= offsetAngledX;
                                    y += offsetAngledY;
                                }
                            },
                        }
                        switch (direction) {
                            0 => {
                                verticesMiddleDotted(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            1 => {
                                verticesMiddleArrowed(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            2 => {
                                verticesMiddleZigZag(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                            else => {
                                verticesMiddleLine(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                            },
                        }
                    }
                } else {
                    var rotation: f32 = 0;
                    switch (moveDirection) {
                        movePieceZig.DIRECTION_UP => {
                            rotation = std.math.pi * 3.0 / 2.0;
                        },
                        movePieceZig.DIRECTION_DOWN => {
                            rotation = std.math.pi / 2.0;
                        },
                        movePieceZig.DIRECTION_LEFT => {
                            rotation = std.math.pi;
                        },
                        else => {},
                    }
                    switch (direction) {
                        0 => {
                            verticesMiddleDotted(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                        },
                        1 => {
                            verticesMiddleArrowed(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                        },
                        2 => {
                            verticesMiddleZigZag(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                        },
                        else => {
                            verticesMiddleLine(x, y, baseWidth, baseHeight, rotation, lineColor, lines);
                        },
                    }
                }
            }
            if (player.equipment.hasWeaponKunai) {
                const kunaiRange = equipmentZig.KUNAI_RANGE;
                for (1..kunaiRange + 1) |i| {
                    const fi: f32 = @floatFromInt(i);
                    const gamePosition: main.Position = .{
                        .x = gamePositionWithCameraOffset.x + state.camera.position.x + moveX * fi,
                        .y = gamePositionWithCameraOffset.y + state.camera.position.y + moveY * fi,
                    };
                    paintVulkanZig.verticesForComplexSpriteAlpha(gamePosition, imageZig.IMAGE_KUNAI_TILE_INDICATOR, 0.25, state);
                }
            }
        }
        if (player.equipment.hasWeaponHammer) {
            const hammerPositionOffsets = [_]main.Position{
                .{ .x = -main.TILESIZE, .y = -main.TILESIZE },
                .{ .x = 0, .y = -main.TILESIZE },
                .{ .x = main.TILESIZE, .y = -main.TILESIZE },
                .{ .x = -main.TILESIZE, .y = 0 },
                .{ .x = main.TILESIZE, .y = 0 },
                .{ .x = -main.TILESIZE, .y = main.TILESIZE },
                .{ .x = 0, .y = main.TILESIZE },
                .{ .x = main.TILESIZE, .y = main.TILESIZE },
            };
            const oppositeMoveDirection = @mod(moveDirection + 2, 4);
            const stepDirection = movePieceZig.getStepDirection(oppositeMoveDirection);
            for (0..hammerPositionOffsets.len) |i| {
                if (hammerPositionOffsets[i].x == stepDirection.x * main.TILESIZE and hammerPositionOffsets[i].y == stepDirection.y * main.TILESIZE) continue;
                const gamePosition: main.Position = .{
                    .x = gamePositionWithCameraOffset.x + state.camera.position.x + hammerPositionOffsets[i].x,
                    .y = gamePositionWithCameraOffset.y + state.camera.position.y + hammerPositionOffsets[i].y,
                };
                paintVulkanZig.verticesForComplexSpriteAlpha(gamePosition, imageZig.IMAGE_HAMMER_TILE_INDICATOR, 0.25, state);
            }
        }
    }
}

fn verticesForArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.5, .y = -0.20 },
        .{ .x = 0.0, .y = -0.20 },
        .{ .x = 0.0, .y = -0.5 },
        .{ .x = 0.5, .y = 0 },
        .{ .x = 0.0, .y = 0.5 },
        .{ .x = 0.0, .y = 0.20 },
        .{ .x = -0.5, .y = 0.20 },
        .{ .x = -0.5, .y = -0.20 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var angle: f32 = 0;
    switch (arrowDirection) {
        movePieceZig.DIRECTION_UP => {
            angle = std.math.pi * 3.0 / 2.0;
        },
        movePieceZig.DIRECTION_DOWN => {
            angle = std.math.pi / 2.0;
        },
        movePieceZig.DIRECTION_LEFT => {
            angle = std.math.pi;
        },
        else => {},
    }
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, angle);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, angle);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

pub fn verticesForFilledArrowGame(gamePosition: main.Position, size: f32, arrowDirection: u8, fillColor: [4]f32, state: *main.GameState) void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const vulkan: main.Position = .{
        .x = (gamePosition.x - state.camera.position.x - main.TILESIZE / 2) * state.camera.zoom * onePixelXInVulkan,
        .y = (gamePosition.y - state.camera.position.y - main.TILESIZE / 2) * state.camera.zoom * onePixelYInVulkan,
    };
    const vulkanWidth = size * onePixelXInVulkan * state.camera.zoom;
    const vulkanHeight = size * onePixelYInVulkan * state.camera.zoom;
    verticesForFilledArrow(vulkan.x, vulkan.y, vulkanWidth, vulkanHeight, arrowDirection, fillColor, &state.vkState.verticeData.lines, &state.vkState.verticeData.triangles);
}

fn verticesForFilledArrow(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, arrowDirection: u8, fillColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes, triangles: *dataVulkanZig.VkColoredVertexes) void {
    if (triangles.verticeCount + 9 >= triangles.vertices.len) return;
    const lineColor: [4]f32 = .{ 0, 0, 0, 1 };
    var angle: f32 = 0;
    switch (arrowDirection) {
        movePieceZig.DIRECTION_UP => {
            angle = std.math.pi * 3.0 / 2.0;
        },
        movePieceZig.DIRECTION_DOWN => {
            angle = std.math.pi / 2.0;
        },
        movePieceZig.DIRECTION_LEFT => {
            angle = std.math.pi;
        },
        else => {},
    }
    const offsets = [_]main.Position{
        main.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = -0.5 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.5, .y = 0 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = 0.5 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = 0.0, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = -0.5, .y = 0.20 }, .{ .x = 0, .y = 0 }, angle),
        main.rotateAroundPoint(.{ .x = -0.5, .y = -0.20 }, .{ .x = 0, .y = 0 }, angle),
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var pos: [offsets.len]main.Position = undefined;
    for (0..pos.len) |i| {
        pos[i] = .{ .x = vulkanX + vulkanTileWidth * offsets[i].x, .y = vulkanY + vulkanTileHeight * offsets[i].y };
    }
    var lastPos: main.Position = .{ .x = 0, .y = 0 };
    var currentPos: main.Position = pos[0];
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        currentPos = pos[i];
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[0].x, pos[0].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[1].x, pos[1].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[5].x, pos[5].y }, .color = fillColor };
    triangles.verticeCount += 3;
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[0].x, pos[0].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[5].x, pos[5].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[6].x, pos[6].y }, .color = fillColor };
    triangles.verticeCount += 3;
    triangles.vertices[triangles.verticeCount + 0] = .{ .pos = .{ pos[2].x, pos[2].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 1] = .{ .pos = .{ pos[3].x, pos[3].y }, .color = fillColor };
    triangles.vertices[triangles.verticeCount + 2] = .{ .pos = .{ pos[4].x, pos[4].y }, .color = fillColor };
    triangles.verticeCount += 3;
}

fn verticesForSquare(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.45, .y = -0.45 },
        .{ .x = 0.45, .y = -0.45 },
        .{ .x = 0.45, .y = 0.45 },
        .{ .x = -0.45, .y = 0.45 },
        .{ .x = -0.45, .y = -0.45 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * offsets[0].x, .y = vulkanY + vulkanTileHeight * offsets[0].y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        currentPos = .{ .x = vulkanX + vulkanTileWidth * offsets[i].x, .y = vulkanY + vulkanTileHeight * offsets[i].y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleLine(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleZigZag(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0.2 },
        .{ .x = -0.1, .y = -0.2 },
        .{ .x = 0.1, .y = 0.2 },
        .{ .x = 0.3, .y = -0.2 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    var lastPos: main.Position = .{ .x = vulkanX, .y = vulkanY };
    var rotatedOffset = main.rotateAroundPoint(offsets[0], .{ .x = 0, .y = 0 }, rotation);
    var currentPos: main.Position = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
    for (1..offsets.len) |i| {
        lastPos = currentPos;
        rotatedOffset = main.rotateAroundPoint(offsets[i], .{ .x = 0, .y = 0 }, rotation);
        currentPos = .{ .x = vulkanX + vulkanTileWidth * rotatedOffset.x, .y = vulkanY + vulkanTileHeight * rotatedOffset.y };
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ lastPos.x, lastPos.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ currentPos.x, currentPos.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleDotted(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.4, .y = 0 },
        .{ .x = -0.3, .y = 0 },
        .{ .x = -0.1, .y = 0 },
        .{ .x = 0.0, .y = 0 },
        .{ .x = 0.2, .y = 0 },
        .{ .x = 0.3, .y = 0 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    for (0..@divFloor(offsets.len, 2)) |i| {
        const rotatedOffset = main.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = main.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

fn verticesMiddleArrowed(vulkanX: f32, vulkanY: f32, vulkanTileWidth: f32, vulkanTileHeight: f32, rotation: f32, lineColor: [4]f32, lines: *dataVulkanZig.VkColoredVertexes) void {
    const offsets = [_]main.Position{
        .{ .x = -0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.15, .y = -0.15 },
        .{ .x = 0.3, .y = 0 },
        .{ .x = 0.15, .y = 0.15 },
    };
    if (lines.verticeCount + 2 * offsets.len >= lines.vertices.len) return;
    for (0..@divFloor(offsets.len, 2)) |i| {
        const rotatedOffset = main.rotateAroundPoint(offsets[i * 2], .{ .x = 0, .y = 0 }, rotation);
        const rotatedOffset2 = main.rotateAroundPoint(offsets[i * 2 + 1], .{ .x = 0, .y = 0 }, rotation);
        lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset.x, vulkanY + vulkanTileHeight * rotatedOffset.y }, .color = lineColor };
        lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ vulkanX + vulkanTileWidth * rotatedOffset2.x, vulkanY + vulkanTileHeight * rotatedOffset2.y }, .color = lineColor };
        lines.verticeCount += 2;
    }
}

pub fn isChoosenPieceVisualizationOverlapping(movePiece: movePieceZig.MovePiece) bool {
    var x1: i32 = 0;
    var y1: i32 = 0;
    for (0..movePiece.steps.len) |movePieceIndex1| {
        const movePiece1Steps = movePiece.steps[movePieceIndex1];
        const stepDirection = movePieceZig.getStepDirectionTile(movePiece1Steps.direction);
        for (0..movePiece1Steps.stepCount) |stepCount1| {
            x1 += stepDirection.x;
            y1 += stepDirection.y;
            if (x1 == 0 and y1 == 0) return true;
            var x2: i32 = x1;
            var y2: i32 = y1;
            for (movePieceIndex1..movePiece.steps.len) |movePieceIndex2| {
                const stepCount2Start = if (movePieceIndex2 == movePieceIndex1) stepCount1 + 1 else 0;
                const movePiece2Steps = movePiece.steps[movePieceIndex2];
                const stepDirection2 = movePieceZig.getStepDirectionTile(movePiece2Steps.direction);
                for (stepCount2Start..movePiece2Steps.stepCount) |_| {
                    x2 += stepDirection2.x;
                    y2 += stepDirection2.y;
                    if ((x1 == y2 and y1 == -x2) or (x1 == -x2 and y1 == -y2) or (x1 == -y2 and y1 == x2)) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}
