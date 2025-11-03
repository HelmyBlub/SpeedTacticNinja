const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const movePieceZig = @import("../movePiece.zig");
const enemyObjectZig = @import("enemyObject.zig");
const enemyTypeAttackZig = @import("enemyTypeAttack.zig");
const enemyTypeMoveZig = @import("enemyTypeMove.zig");
const enemyTypeMoveWithPlayerZig = @import("enemyTypeMoveWithPlayer.zig");
const enemyTypeProjectileAttackZig = @import("enemyTypeProjectileAttack.zig");
const enemyTypePutFireZig = @import("enemyTypePutFire.zig");
const enemyTypeBlockZig = @import("enemyTypeBlock.zig");
const enemyTypeIceAttackZig = @import("enemyTypeIceAttack.zig");
const enemyTypeWallerZig = @import("enemyTypeWaller.zig");
const enemyTypeMovePieceZig = @import("enemyTypeMovePiece.zig");
const enemyTypeBombZig = @import("enemyTypeBomb.zig");
const mapTileZig = @import("../mapTile.zig");
const playerZig = @import("../player.zig");

pub const EnemyData = struct {
    enemies: std.ArrayList(Enemy) = undefined,
    enemySpawnData: EnemySpawnData = undefined,
    enemyObjects: std.ArrayList(enemyObjectZig.EnemyObject) = undefined,
    afterImages: std.ArrayList(EnemyAfterImage) = undefined,
    movePieceEnemyMovePiece: ?movePieceZig.MovePiece = null,
    bombEnemyMovePiece: movePieceZig.MovePiece = undefined,
};

pub const EnemyAfterImage = struct {
    position: main.Position,
    imageIndex: u8,
    deleteTime: i64,
};

pub const EnemyFunctions = struct {
    createSpawnEnemyEntryEnemy: *const fn (state: *main.GameState) Enemy,
    tick: ?*const fn (enemy: *Enemy, passedTime: i64, state: *main.GameState) anyerror!void = null,
    onPlayerMoved: ?*const fn (enemy: *Enemy, player: *playerZig.Player, state: *main.GameState) anyerror!void = null,
    onPlayerMoveEachTile: ?*const fn (enemy: *Enemy, player: *playerZig.Player, state: *main.GameState) anyerror!void = null,
    setupVertices: ?*const fn (enemy: *Enemy, state: *main.GameState) void = null,
    setupVerticesGround: ?*const fn (enemy: *Enemy, state: *main.GameState) anyerror!void = null,
    isEnemyHit: ?*const fn (enemy: *Enemy, hitArea: main.TileRectangle, hitDirection: u8, state: *main.GameState) anyerror!bool = null,
    scaleEnemyForNewGamePlus: ?*const fn (enemy: *Enemy, newGamePlus: u32) void = null,
};

pub const EnemyType = enum {
    nothing,
    attack,
    move,
    moveWithPlayer,
    projectileAttack,
    putFire,
    block,
    ice,
    waller,
    movePiece,
    bomb,
};

pub const EnemyTypeData = union(EnemyType) {
    nothing,
    attack: enemyTypeAttackZig.EnemyTypeAttackData,
    move: EnemyTypeDelayedActionData,
    moveWithPlayer: enemyTypeMoveWithPlayerZig.EnemyTypeMoveWithPlayerData,
    projectileAttack: enemyTypeProjectileAttackZig.EnemyTypeDelayedProjectileActionData,
    putFire: enemyTypePutFireZig.EnemyTypePutFireData,
    block: enemyTypeBlockZig.EnemyTypeBlockData,
    ice: enemyTypeIceAttackZig.DelayedAttackWithCooldown,
    waller: enemyTypeWallerZig.EnemyTypeWallerData,
    movePiece: enemyTypeMovePieceZig.EnemyTypeMovePieceData,
    bomb: enemyTypeBombZig.EnemyTypeBombData,
};

pub const ENEMY_FUNCTIONS = std.EnumArray(EnemyType, EnemyFunctions).init(.{
    .nothing = .{ .createSpawnEnemyEntryEnemy = nothingEntryEnemy },
    .attack = enemyTypeAttackZig.create(),
    .move = enemyTypeMoveZig.create(),
    .moveWithPlayer = enemyTypeMoveWithPlayerZig.create(),
    .projectileAttack = enemyTypeProjectileAttackZig.create(),
    .putFire = enemyTypePutFireZig.create(),
    .block = enemyTypeBlockZig.create(),
    .ice = enemyTypeIceAttackZig.create(),
    .waller = enemyTypeWallerZig.create(),
    .movePiece = enemyTypeMovePieceZig.create(),
    .bomb = enemyTypeBombZig.create(),
});

const ENEMY_TYPE_SPAWN_LEVEL_DATA = [_]EnemyTypeSpawnLevelData{
    .{ .baseProbability = 0.1, .enemyType = .nothing, .startingLevel = 1, .leavingLevel = 3 },
    .{ .baseProbability = 1, .enemyType = .attack, .startingLevel = 2, .leavingLevel = 10 },
    .{ .baseProbability = 1, .enemyType = .move, .startingLevel = 5, .leavingLevel = 15 },
    .{ .baseProbability = 1, .enemyType = .moveWithPlayer, .startingLevel = 10, .leavingLevel = 20 },
    .{ .baseProbability = 1, .enemyType = .projectileAttack, .startingLevel = 15, .leavingLevel = 25 },
    .{ .baseProbability = 1, .enemyType = .putFire, .startingLevel = 20, .leavingLevel = 30 },
    .{ .baseProbability = 1, .enemyType = .block, .startingLevel = 25, .leavingLevel = 35 },
    .{ .baseProbability = 1, .enemyType = .ice, .startingLevel = 30, .leavingLevel = 40 },
    .{ .baseProbability = 1, .enemyType = .waller, .startingLevel = 35, .leavingLevel = 45 },
    .{ .baseProbability = 1, .enemyType = .movePiece, .startingLevel = 40, .leavingLevel = null },
    .{ .baseProbability = 1, .enemyType = .bomb, .startingLevel = 45, .leavingLevel = null },
};
pub const AFTER_IMAGE_DURATION = 100;

const EnemyTypeSpawnLevelData = struct {
    enemyType: EnemyType,
    startingLevel: u32,
    leavingLevel: ?u32,
    baseProbability: f32,
};

pub const EnemyTypeDelayedActionData = struct {
    delay: i64,
    direction: u8 = 0,
    startTime: ?i64 = null,
};

pub const Enemy = struct {
    imageIndex: u8,
    position: main.Position,
    enemyTypeData: EnemyTypeData,
};

pub const EnemySpawnData = struct {
    enemyEntries: std.ArrayList(EnemySpawnEntry),
};

const EnemySpawnEntry = struct {
    enemy: Enemy,
    probability: f32,
    calcedProbabilityStart: f32 = 0,
    calcedProbabilityEnd: f32 = 0,
};

pub const MoveAttackWarningTile = struct {
    position: main.TilePosition,
    direction: u8,
};

pub fn tickEnemies(passedTime: i64, state: *main.GameState) !void {
    var afterImageIndex: usize = 0;
    while (afterImageIndex < state.enemyData.afterImages.items.len) {
        if (state.enemyData.afterImages.items[afterImageIndex].deleteTime <= state.gameTime) {
            _ = state.enemyData.afterImages.swapRemove(afterImageIndex);
        } else {
            afterImageIndex += 1;
        }
    }
    for (state.enemyData.enemies.items) |*enemy| {
        if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).tick) |tick| try tick(enemy, passedTime, state);
    }
    try enemyObjectZig.tick(passedTime, state);
}

pub fn onPlayerMoved(player: *playerZig.Player, state: *main.GameState) !void {
    for (state.enemyData.enemies.items) |*enemy| {
        if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).onPlayerMoved) |moved| try moved(enemy, player, state);
    }
}

pub fn onPlayerMoveEachTile(player: *playerZig.Player, state: *main.GameState) !void {
    for (state.enemyData.enemies.items) |*enemy| {
        if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).onPlayerMoveEachTile) |moved| try moved(enemy, player, state);
    }
}

pub fn createSpawnEnemyEntryEnemy(enemyType: EnemyType, state: *main.GameState) Enemy {
    return ENEMY_FUNCTIONS.get(enemyType).createSpawnEnemyEntryEnemy(state);
}

fn nothingEntryEnemy(state: *main.GameState) Enemy {
    _ = state;
    return .{ .enemyTypeData = .nothing, .imageIndex = imageZig.IMAGE_EVIL_TREE, .position = .{ .x = 0, .y = 0 } };
}

pub fn isEnemyHit(enemy: *Enemy, hitArea: main.TileRectangle, hitDirection: u8, state: *main.GameState) !bool {
    if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).isEnemyHit) |enemyHit| {
        return enemyHit(enemy, hitArea, hitDirection, state);
    } else {
        const enemyTile = main.gamePositionToTilePosition(enemy.position);
        return main.isTilePositionInTileRectangle(enemyTile, hitArea);
    }
}

pub fn fillMoveAttackWarningTiles(startPosition: main.Position, tileList: *std.ArrayList(MoveAttackWarningTile), movePiece: movePieceZig.MovePiece, direction: u8) !void {
    var curTilePos = main.gamePositionToTilePosition(startPosition);
    for (movePiece.steps, 0..) |step, stepIndex| {
        const currDirection = @mod(step.direction + direction + 1, 4);
        const stepDirection = movePieceZig.getStepDirectionTile(currDirection);
        for (0..step.stepCount) |stepCountIndex| {
            curTilePos.x += stepDirection.x;
            curTilePos.y += stepDirection.y;
            var visualizedDirection = currDirection;
            if (stepCountIndex == step.stepCount - 1 and movePiece.steps.len > stepIndex + 1) {
                visualizedDirection = @mod(movePiece.steps[stepIndex + 1].direction + direction + 1, 4);
            }
            try tileList.append(.{ .direction = visualizedDirection, .position = curTilePos });
        }
    }
}

pub fn initEnemy(state: *main.GameState) !void {
    state.enemyData.enemies = std.ArrayList(Enemy).init(state.allocator);
    state.enemyData.enemySpawnData.enemyEntries = std.ArrayList(EnemySpawnEntry).init(state.allocator);
    state.enemyData.enemyObjects = std.ArrayList(enemyObjectZig.EnemyObject).init(state.allocator);
    state.enemyData.afterImages = std.ArrayList(EnemyAfterImage).init(state.allocator);
    try enemyTypeBombZig.setupMovePiece(state);
    try setupSpawnEnemiesOnLevelChange(state);
}

pub fn setupSpawnEnemiesOnLevelChange(state: *main.GameState) !void {
    const enemySpawnData = &state.enemyData.enemySpawnData;
    enemySpawnData.enemyEntries.clearRetainingCapacity();
    for (ENEMY_TYPE_SPAWN_LEVEL_DATA) |data| {
        var enemyType = data.enemyType;
        if (data.enemyType == .nothing and state.newGamePlus > 0) enemyType = .attack;
        if (data.startingLevel <= state.level and (data.leavingLevel == null or data.leavingLevel.? > state.level)) {
            try enemySpawnData.enemyEntries.append(.{ .probability = 1, .enemy = createSpawnEnemyEntryEnemy(enemyType, state) });
        }
    }
    scaleEnemiesProbabilityToLevel(state);
}

fn scaleEnemiesProbabilityToLevel(state: *main.GameState) void {
    const level = @mod(state.level, main.LEVEL_COUNT);
    for (state.enemyData.enemySpawnData.enemyEntries.items) |*entry| {
        for (ENEMY_TYPE_SPAWN_LEVEL_DATA) |data| {
            if (entry.enemy.enemyTypeData == data.enemyType) {
                const baseProbability = data.baseProbability;
                const enemyLevel = level -| data.startingLevel + 1;
                const levelDependentProbability = @min(1, @as(f32, @floatFromInt(enemyLevel)) / 10.0);
                entry.probability = baseProbability * levelDependentProbability;
                break;
            }
        }
    }
    calcAndSetEnemySpawnProbabilities(&state.enemyData.enemySpawnData);
}

pub fn destroyEnemyData(state: *main.GameState) void {
    state.enemyData.enemySpawnData.enemyEntries.deinit();
    state.enemyData.enemies.deinit();
    state.enemyData.enemyObjects.deinit();
    state.enemyData.afterImages.deinit();
    if (state.enemyData.movePieceEnemyMovePiece) |movePiece| {
        state.allocator.free(movePiece.steps);
    }
    state.allocator.free(state.enemyData.bombEnemyMovePiece.steps);
}

pub fn checkStationaryPlayerHit(position: main.Position, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.executeMovePiece == null) {
            if (player.position.x > position.x - main.TILESIZE / 2 and player.position.x < position.x + main.TILESIZE / 2 and
                player.position.y > position.y - main.TILESIZE / 2 and player.position.y < position.y + main.TILESIZE / 2)
            {
                try playerZig.playerHit(player, state);
            }
        }
    }
}

pub fn checkPlayerHit(position: main.Position, state: *main.GameState) !void {
    for (state.players.items) |*player| {
        if (player.position.x > position.x - main.TILESIZE / 2 and player.position.x < position.x + main.TILESIZE / 2 and
            player.position.y > position.y - main.TILESIZE / 2 and player.position.y < position.y + main.TILESIZE / 2)
        {
            try playerZig.playerHit(player, state);
        }
    }
}

pub fn setupEnemies(state: *main.GameState) !void {
    const enemies = &state.enemyData.enemies;
    enemies.clearRetainingCapacity();
    if (state.enemyData.enemySpawnData.enemyEntries.items.len == 0) return;
    const rand = state.seededRandom.random();
    const enemyCountForLevel = @min(state.config.maxEnemyLevelStartCount -| 1, (@divFloor(state.level - 1, 2) + state.newGamePlus));
    const enemyCount = @max((state.round + enemyCountForLevel) * state.players.items.len, state.config.minEnemyLevelStartCount);
    const mapTileRadiusWidth = mapTileZig.BASE_MAP_TILE_RADIUS + @as(u32, @intFromFloat(@sqrt(@as(f32, @floatFromInt(enemyCount)))));
    const mapTileRadiusHeight = mapTileRadiusWidth;
    try mapTileZig.setMapRadius(mapTileRadiusWidth, mapTileRadiusHeight, state);
    const lengthX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * 2 + 1);
    const lengthY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * 2 + 1);
    while (enemies.items.len < enemyCount) {
        const randomTileX: i16 = @as(i16, @intFromFloat(rand.float(f32) * lengthX - lengthX / 2));
        const randomTileY: i16 = @as(i16, @intFromFloat(rand.float(f32) * lengthY - lengthY / 2));
        const randomPos: main.Position = .{
            .x = @floatFromInt(randomTileX * main.TILESIZE),
            .y = @floatFromInt(randomTileY * main.TILESIZE),
        };
        if (main.isPositionEmpty(randomPos, state)) {
            const randomFloat = state.seededRandom.random().float(f32);
            if (enemies.items.len < state.enemyData.enemySpawnData.enemyEntries.items.len) {
                var enemy = state.enemyData.enemySpawnData.enemyEntries.items[enemies.items.len].enemy;
                enemy.position = randomPos;
                if (state.newGamePlus > 0) {
                    if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).scaleEnemyForNewGamePlus) |scale| scale(&enemy, state.newGamePlus);
                }
                try enemies.append(enemy);
            } else {
                for (state.enemyData.enemySpawnData.enemyEntries.items) |entry| {
                    if (randomFloat >= entry.calcedProbabilityStart and randomFloat < entry.calcedProbabilityEnd) {
                        var enemy = entry.enemy;
                        enemy.position = randomPos;
                        if (state.newGamePlus > 0) {
                            if (ENEMY_FUNCTIONS.get(enemy.enemyTypeData).scaleEnemyForNewGamePlus) |scale| scale(&enemy, state.newGamePlus);
                        }
                        try enemies.append(enemy);
                    }
                }
            }
        }
    }
}

pub fn calcAndSetEnemySpawnProbabilities(enemySpawnData: *EnemySpawnData) void {
    var totalProbability: f32 = 0;
    for (enemySpawnData.enemyEntries.items) |entry| {
        totalProbability += entry.probability;
    }
    var currentProbability: f32 = 0;
    for (enemySpawnData.enemyEntries.items) |*entry| {
        entry.calcedProbabilityStart = currentProbability;
        currentProbability += entry.probability / totalProbability;
        entry.calcedProbabilityEnd = currentProbability;
    }
    if (enemySpawnData.enemyEntries.items.len > 0) {
        enemySpawnData.enemyEntries.items[enemySpawnData.enemyEntries.items.len - 1].calcedProbabilityEnd = 1;
    }
}
