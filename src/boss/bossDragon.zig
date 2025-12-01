const std = @import("std");
const main = @import("../main.zig");
const imageZig = @import("../image.zig");
const bossZig = @import("boss.zig");
const soundMixerZig = @import("../soundMixer.zig");
const enemyVulkanZig = @import("../vulkan/enemyVulkan.zig");
const paintVulkanZig = @import("../vulkan/paintVulkan.zig");
const mapTileZig = @import("../mapTile.zig");
const enemyObjectFireZig = @import("../enemy/enemyObjectFire.zig");
const movePieceZig = @import("../movePiece.zig");
const playerZig = @import("../player.zig");

const DragonPhase = enum {
    phase1,
    phase2,
    phase3,
};

const DragonAction = enum {
    flyingOver,
    landing,
    landingStomp,
    bodyStomp,
    transitionFlyingPhase,
    wingBlast,
    fireBreath,
    tailAttack,
};

const DragonActionData = union(DragonAction) {
    flyingOver: DragonMoveData,
    landing: DragonMoveData,
    landingStomp: LandingStompData,
    bodyStomp: BodyStompData,
    transitionFlyingPhase: TransitionFlyingData,
    wingBlast: WingBlastData,
    fireBreath: FireBreathData,
    tailAttack: TailAttackhData,
};

const TailAttackhData = struct {
    tailAttackHitTime: ?i64 = null,
    tailAttackDelay: i32 = 2000,
};

const FireBreathData = struct {
    nextFireSpitTickTime: ?i64 = null,
    firstFireSpitDelay: i32 = 2000,
    spitInterval: i32 = 100,
    targetPlayerIndex: usize = 0,
    spitEndTime: i64 = 0,
    spitDuration: i32 = 2500,
};

const WingBlastData = struct {
    direction: ?u8 = null,
    nextMoveTickTime: ?i64 = null,
    firstMoveTickDelay: i32 = 2000,
    moveInterval: i32 = 250,
    maxMoveTicks: u16 = 10,
    moveTickCount: u16 = 0,
};

const DragonMoveData = struct {
    targetPos: main.Position,
};

const LandingStompData = struct {
    stompTime: ?i64 = null,
    stompHeight: f32 = 0,
    delay: i32 = 2000,
};

const BodyStompData = struct {
    stompTime: ?i64 = null,
    standUpMaxPerCent: f32 = 0,
    delay: i32 = 1750,
    latestStompStartTime: ?i64 = null,
};

const TransitionFlyingData = struct {
    keepCameraUntilTime: ?i64 = null,
    moveCameraToDefaultTime: ?i64 = null,
    cameraDone: bool = false,
    dragonFlyPositionIndex: usize = 0,
    fireSpawnTile: ?i32 = null,
    targetPlayerIndex: ?usize = null,
};

pub const BossDragonData = struct {
    newGamePlus: u32 = 0,
    action: DragonActionData,
    phase: DragonPhase = .phase1,
    nextStateTime: ?i64 = null,
    inAirHeight: f32 = DEFAULT_FYLING_HEIGHT,
    direction: f32 = 0,
    movingFeetPair1: bool = false,
    openMouth: bool = false,
    moveSpeed: f32 = DEFAULT_MOVE_SPEED,
    fireAbilitiesSinceLastWingBlast: u32 = 0,
    feetOffset: [4]main.Position = [4]main.Position{
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
        .{ .x = 0, .y = 0 },
    },
    paint: struct {
        standingPerCent: f32 = 0,
        mouthOpenPerCent: f32 = 0,
        tailUpPerCent: f32 = 0,
        wingsFlapStarted: ?i64 = null,
        wingFlapSpeedFactor: f32 = 1,
        stopWings: bool = false,
        rotation: f32 = 0,
        alpha: f32 = 1,
        lastAttackRectangle: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
        visualizeAttackPosition: ?i64 = null,
    } = .{},
    soundData: struct {
        windSoundPlayer: bool = false,
        lastFireBreathTime: ?i64 = null,
    } = .{},
    attackTiles: std.ArrayList(main.TilePosition),
};

const ATTACK_VISAULIZE_DURATION = 200;
const DEFAULT_FYLING_HEIGHT = 150;
const BOSS_NAME = "Dragon";
const LANDING_STOMP_AREA_RADIUS_X = 2;
const LANDING_STOMP_AREA_RADIUS_Y = 1;
const LANDING_STOMP_AREA_OFFSET: main.Position = .{ .x = 0, .y = -main.TILESIZE };
const BODY_STOMP_AREA_RADIUS_X = 2;
const BODY_STOMP_AREA_RADIUS_Y = 2;
const STAND_UP_SPEED = 0.0005;
const FLYING_TRANSITION_CAMERA_WAIT_TIME = 2000;
const FLYING_TRANSITION_CAMERA_MOVE_DURATION = 2000;
const FLYING_TRANSITION_CAMERA_OFFSET_Y = -300;
const DEFAULT_FLYING_SPEED = 0.3;
const DEFAULT_MOVE_SPEED = 0.02;
const DEFAULT_FEET_OFFSET = [4]main.Position{
    .{ .x = -1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = -1 * main.TILESIZE },
    .{ .x = -1 * main.TILESIZE, .y = 1 * main.TILESIZE },
    .{ .x = 1 * main.TILESIZE, .y = 1 * main.TILESIZE },
};
const FLYING_TRANSITION_DRAGON_POSITIONS = [4]main.Position{
    .{ .x = 25 * main.TILESIZE, .y = 0 },
    .{ .x = -25 * main.TILESIZE, .y = 0 },
    .{ .x = 0, .y = 25 * main.TILESIZE },
    .{ .x = 0, .y = -25 * main.TILESIZE },
};
const PHASE_2_TRANSITION_PER_CENT = 0.80;
const PHASE_3_TRANSITION_PER_CENT = 0.50;

pub fn createBoss() bossZig.LevelBossData {
    return bossZig.LevelBossData{
        .appearsOnLevel = 50,
        .startLevel = startBoss,
        .tickBoss = tickBoss,
        .isBossHit = isBossHit,
        .setupVertices = setupVertices,
        .setupVerticesGround = setupVerticesGround,
        .onPlayerMoveEachTile = onPlayerMoveEachTile,
        .deinit = deinit,
        .imageIndex = imageZig.IMAGE_BOSS_DRAGON_HEAD,
    };
}

fn deinit(boss: *bossZig.Boss, allocator: std.mem.Allocator) void {
    _ = allocator;
    const data = &boss.typeData.dragon;
    data.attackTiles.deinit();
}

fn startBoss(state: *main.GameState) !void {
    const baseHp = 50;
    const levelScaledHp = bossZig.getHpScalingForLevel(baseHp, state);
    const scaledHp: u32 = levelScaledHp * @as(u32, @intCast(state.players.items.len));
    var boss: bossZig.Boss = .{
        .hp = scaledHp,
        .maxHp = scaledHp,
        .imageIndex = imageZig.IMAGE_BOSS_DRAGON_TAIL,
        .position = .{ .x = 0, .y = 800 },
        .name = BOSS_NAME,
        .typeData = .{ .dragon = .{
            .action = .{ .flyingOver = .{ .targetPos = .{ .x = 0, .y = -300 } } },
            .attackTiles = std.ArrayList(main.TilePosition).init(state.allocator),
        } },
    };
    boss.typeData.dragon.newGamePlus = state.newGamePlus;
    boss.typeData.dragon.paint.wingsFlapStarted = state.gameTime;
    boss.typeData.dragon.paint.stopWings = false;
    try mapTileZig.setMapRadius(6, 6, state);
    main.adjustZoom(state);
    mapTileZig.setMapType(.top, state);
    try state.bosses.append(boss);
}

fn onPlayerMoveEachTile(boss: *bossZig.Boss, player: *playerZig.Player, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    switch (data.action) {
        .fireBreath => |*fireBreathData| {
            if (fireBreathData.nextFireSpitTickTime != null and fireBreathData.spitEndTime - fireBreathData.spitDuration <= state.gameTime) {
                if (player == &state.players.items[fireBreathData.targetPlayerIndex]) {
                    fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.spitInterval;
                    const targetPos = player.position;
                    try enemyObjectFireZig.spawnEternalFire(boss.position, targetPos, 100, state);
                }
            }
        },
        else => {},
    }
}

fn tickBoss(boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    switch (data.action) {
        .flyingOver => |actionData| {
            if (moveBossTick(boss, actionData.targetPos, passedTime, DEFAULT_FLYING_SPEED)) {
                data.paint.standingPerCent = 1;
                data.action = .{ .landing = .{ .targetPos = .{ .x = 0, .y = 0 } } };
            }
        },
        .landing => |actionData| {
            const direction = main.calculateDirection(boss.position, actionData.targetPos);
            data.direction = direction;
            const landingSpeed = 0.1;
            const distance: f32 = landingSpeed * @as(f32, @floatFromInt(passedTime));
            boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
            const distanceToTarget = main.calculateDistance(boss.position, actionData.targetPos);
            if (distanceToTarget < data.inAirHeight * 0.75) {
                data.inAirHeight = @max(0, data.inAirHeight - distance);
            }
            if (distanceToTarget <= landingSpeed * 16) {
                boss.position = actionData.targetPos;
                setAction(.{ .landingStomp = .{} }, boss);
                data.paint.stopWings = true;
            }
        },
        .landingStomp => |*stompData| {
            if (stompData.stompTime == null) stompData.stompTime = state.gameTime + stompData.delay;
            const stompPerCent: f32 = 1 - @max(0, @as(f32, @floatFromInt(stompData.stompTime.? - state.gameTime)) / @as(f32, @floatFromInt(stompData.delay)));
            const stompStartPerCent = 0.9;
            if (stompPerCent < stompStartPerCent) {
                const distanceUp: f32 = 0.02 * @as(f32, @floatFromInt(passedTime));
                data.inAirHeight += distanceUp;
                stompData.stompHeight = data.inAirHeight;
            } else {
                data.inAirHeight = stompData.stompHeight * @sqrt((1 - stompPerCent) / (1 - stompStartPerCent));
            }
            if (stompData.stompTime.? <= state.gameTime) {
                data.inAirHeight = 0;
                try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_STOMP_INDICIES[0..], 0, 1);
                const attackTileCenter = main.gamePositionToTilePosition(.{ .x = boss.position.x + LANDING_STOMP_AREA_OFFSET.x, .y = boss.position.y + LANDING_STOMP_AREA_OFFSET.y });
                const damageTileRectangle: main.TileRectangle = .{
                    .pos = .{ .x = attackTileCenter.x - LANDING_STOMP_AREA_RADIUS_X, .y = attackTileCenter.y - LANDING_STOMP_AREA_RADIUS_Y },
                    .width = LANDING_STOMP_AREA_RADIUS_X * 2 + 1,
                    .height = LANDING_STOMP_AREA_RADIUS_Y * 2 + 1,
                };
                for (state.players.items) |*player| {
                    const playerTile = main.gamePositionToTilePosition(player.position);
                    if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                        try playerZig.playerHit(player, state);
                    }
                }
                data.paint.visualizeAttackPosition = state.gameTime + ATTACK_VISAULIZE_DURATION;
                data.paint.lastAttackRectangle = .{
                    .pos = .{ .x = @as(f32, @floatFromInt(damageTileRectangle.pos.x)) * main.TILESIZE, .y = @as(f32, @floatFromInt(damageTileRectangle.pos.y)) * main.TILESIZE },
                    .width = @as(f32, @floatFromInt(damageTileRectangle.width)) * main.TILESIZE,
                    .height = @as(f32, @floatFromInt(damageTileRectangle.height)) * main.TILESIZE,
                };
                chooseNextAttack(boss, state);
            }
        },
        .bodyStomp => |*stompData| {
            try tickBodyStomp(stompData, boss, passedTime, state);
        },
        .transitionFlyingPhase => |*flyingData| {
            try tickTransitionFlyingPhase(flyingData, boss, passedTime, state);
        },
        .wingBlast => |*wingBlastData| {
            try tickWingBlastAction(wingBlastData, boss, passedTime, state);
        },
        .fireBreath => |*fireBreathData| {
            try tickFireBreathAction(fireBreathData, boss, passedTime, state);
        },
        .tailAttack => |*tailAttackhData| {
            try tickTailAttackAction(tailAttackhData, boss, passedTime, state);
        },
    }
    adjustFeetToTiles(boss, passedTime);
    if (data.openMouth) {
        if (data.paint.mouthOpenPerCent < 1) {
            data.paint.mouthOpenPerCent += @as(f32, @floatFromInt(passedTime)) * 0.001;
            if (data.paint.mouthOpenPerCent > 1) data.paint.mouthOpenPerCent = 1;
        }
    } else {
        if (data.paint.mouthOpenPerCent > 0) {
            data.paint.mouthOpenPerCent -= @as(f32, @floatFromInt(passedTime)) * 0.001;
            if (data.paint.mouthOpenPerCent < 0) data.paint.mouthOpenPerCent = 0;
        }
    }
    if (data.paint.wingsFlapStarted) |startedTime| {
        const wingsFlap = @sin(@as(f32, @floatFromInt((state.gameTime - startedTime))) * data.paint.wingFlapSpeedFactor / 200);
        if (@abs(wingsFlap) < 0.1 and !data.soundData.windSoundPlayer) {
            const distance = main.calculateDistance(boss.position, .{ .x = 0, .y = 0 });
            const volume = 1.0 / @max(1.0, (distance - 200) / 50);
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_WIND_INDICIES[0..], 0, volume);
            data.soundData.windSoundPlayer = true;
        } else if (wingsFlap < -0.5 and data.soundData.windSoundPlayer) {
            data.soundData.windSoundPlayer = false;
        }
    }
}

fn tickTailAttackAction(tailAttackData: *TailAttackhData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    const tailRange = 100;
    standUpOrDownTick(boss, false, passedTime, state);
    if (tailAttackData.tailAttackHitTime == null) {
        if (data.paint.standingPerCent < 0.1) {
            const closest = playerZig.getClosestPlayer(boss.position, state);
            data.moveSpeed = DEFAULT_MOVE_SPEED * 2;
            if (closest.player) |player| {
                const direction = main.calculateDirection(player.position, boss.position);
                setDirection(boss, direction);
                if (closest.distance < tailRange) {
                    tailAttackData.tailAttackHitTime = state.gameTime + tailAttackData.tailAttackDelay;
                    try determineTailAttackTiles(boss);
                    data.moveSpeed = DEFAULT_MOVE_SPEED;
                } else {
                    const moveDistance: f32 = data.moveSpeed * @as(f32, @floatFromInt(passedTime));
                    boss.position = main.moveByDirectionAndDistance(boss.position, direction + std.math.pi, moveDistance);
                }
            }
        }
    } else {
        const timePerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(tailAttackData.tailAttackHitTime.? - state.gameTime)) / @as(f32, @floatFromInt(tailAttackData.tailAttackDelay))));
        const tailDownTimeStartPerCent = 0.8;
        if (timePerCent > tailDownTimeStartPerCent) {
            data.paint.tailUpPerCent = @sqrt((1 - timePerCent) / (1 - tailDownTimeStartPerCent));
        } else {
            const tailMoveSpeed: f32 = 0.001 * @as(f32, @floatFromInt(passedTime));
            data.paint.tailUpPerCent = @min(1, data.paint.tailUpPerCent + tailMoveSpeed);
        }
        if (tailAttackData.tailAttackHitTime.? <= state.gameTime) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_TAIL_ATTACK_INDICIES[0..], 0, 1);
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                for (data.attackTiles.items) |tile| {
                    if (playerTile.x == tile.x and playerTile.y == tile.y) {
                        try playerZig.playerHit(player, state);
                        break;
                    }
                }
            }
            data.paint.tailUpPerCent = 0;
            chooseNextAttack(boss, state);
        }
    }
}

fn determineTailAttackTiles(boss: *bossZig.Boss) !void {
    const data = &boss.typeData.dragon;
    data.attackTiles.clearRetainingCapacity();
    const tailLength = 80;
    const tailStart: main.Position = .{
        .x = boss.position.x + @cos(data.direction + std.math.pi) * 20,
        .y = boss.position.y + @sin(data.direction + std.math.pi) * 20,
    };
    const tailAttackWidth = main.TILESIZE * 1.5;
    const tailEnd: main.Position = .{
        .x = tailStart.x + @cos(data.direction + std.math.pi) * tailLength,
        .y = tailStart.y + @sin(data.direction + std.math.pi) * tailLength,
    };
    const startTile = main.gamePositionToTilePosition(tailStart);
    const endTile = main.gamePositionToTilePosition(tailEnd);
    const checkTile: main.TilePosition = .{
        .x = if (startTile.x < endTile.x) startTile.x else endTile.x,
        .y = if (startTile.y < endTile.y) startTile.y else endTile.y,
    };
    const increaseCheckRectangleBy = 1;
    const width: usize = @intCast(@abs(startTile.x - endTile.x) + 1 + increaseCheckRectangleBy * 2);
    const height: usize = @intCast(@abs(startTile.y - endTile.y) + 1 + increaseCheckRectangleBy * 2);
    for (0..width) |i| {
        for (0..height) |j| {
            const tile: main.TilePosition = .{
                .x = checkTile.x + @as(i32, @intCast(i)) - increaseCheckRectangleBy,
                .y = checkTile.y + @as(i32, @intCast(j)) - increaseCheckRectangleBy,
            };
            const checkPosition: main.Position = .{
                .x = @floatFromInt(tile.x * main.TILESIZE),
                .y = @floatFromInt(tile.y * main.TILESIZE),
            };
            const distance = main.calculateDistancePointToLine(checkPosition, tailStart, tailEnd);
            if (distance < tailAttackWidth) {
                try data.attackTiles.append(tile);
            }
        }
    }
}

fn tickFireBreathAction(fireBreathData: *FireBreathData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    standUpOrDownTick(boss, true, passedTime, state);
    if (fireBreathData.nextFireSpitTickTime == null) {
        if (data.paint.standingPerCent > 0.5) {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BREATH_IN, 0, 1);
            fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.firstFireSpitDelay;
            const optRandomPlayerIndex = playerZig.getRandomAlivePlayerIndex(state);
            if (optRandomPlayerIndex) |playerIndex| {
                fireBreathData.targetPlayerIndex = playerIndex;
                fireBreathData.spitEndTime = fireBreathData.nextFireSpitTickTime.? + fireBreathData.spitDuration;
                setDirection(boss, std.math.pi / 2.0);
                data.openMouth = true;
            }
        }
    } else {
        if (fireBreathData.spitEndTime - state.gameTime < fireBreathData.spitDuration and (data.soundData.lastFireBreathTime == null or data.soundData.lastFireBreathTime.? + 650 < state.gameTime)) {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_FIRE_BREATH, 0, 1);
            data.soundData.lastFireBreathTime = state.gameTime;
        }
        if (fireBreathData.nextFireSpitTickTime.? <= state.gameTime) {
            fireBreathData.nextFireSpitTickTime = state.gameTime + fireBreathData.spitInterval;
            const targetPos = state.players.items[fireBreathData.targetPlayerIndex].position;
            try enemyObjectFireZig.spawnEternalFire(boss.position, targetPos, 100, state);
        }
        if (fireBreathData.spitEndTime <= state.gameTime) {
            data.openMouth = false;
            data.fireAbilitiesSinceLastWingBlast += 1;
            chooseNextAttack(boss, state);
        }
    }
}

fn tickWingBlastAction(wingBlastData: *WingBlastData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (wingBlastData.nextMoveTickTime == null) {
        wingBlastData.nextMoveTickTime = state.gameTime + wingBlastData.firstMoveTickDelay;
        wingBlastData.direction = state.seededRandom.random().intRangeLessThan(u8, 0, 4);
        const bossDirection: f32 = @as(f32, @floatFromInt(wingBlastData.direction.?)) * std.math.pi / 2;
        setDirection(boss, bossDirection);
        data.paint.stopWings = false;
        data.paint.wingsFlapStarted = state.gameTime;
        data.paint.wingFlapSpeedFactor = 1;
    } else {
        standUpOrDownTick(boss, true, passedTime, state);
        data.paint.wingFlapSpeedFactor = @min(data.paint.wingFlapSpeedFactor + 0.002, 3);
        const nextMoveTickTime = wingBlastData.nextMoveTickTime.?;
        if (nextMoveTickTime <= state.gameTime) {
            wingBlastData.nextMoveTickTime = state.gameTime + wingBlastData.moveInterval;
            wingBlastData.moveTickCount += 1;
            const stepDirection = movePieceZig.getStepDirection(wingBlastData.direction.?);
            for (state.players.items) |*player| {
                if (player.isDead) continue;
                player.position.x += stepDirection.x * main.TILESIZE;
                player.position.y += stepDirection.y * main.TILESIZE;
                const tilePos = main.gamePositionToTilePosition(player.position);
                if (@abs(tilePos.x) > state.mapData.tileRadiusWidth or @abs(tilePos.y) > state.mapData.tileRadiusHeight) {
                    try playerZig.playerHit(player, state);
                }
            }
            for (state.enemyData.enemyObjects.items) |*object| {
                object.position.x += stepDirection.x * main.TILESIZE;
                object.position.y += stepDirection.y * main.TILESIZE;
                if (object.typeData == .fire and object.typeData.fire.flyToPosition != null) {
                    object.typeData.fire.flyToPosition.?.x += stepDirection.x * main.TILESIZE;
                    object.typeData.fire.flyToPosition.?.y += stepDirection.y * main.TILESIZE;
                }
            }
            if (wingBlastData.maxMoveTicks <= wingBlastData.moveTickCount) {
                data.paint.stopWings = true;
                data.paint.wingFlapSpeedFactor = 1;
                data.fireAbilitiesSinceLastWingBlast = 0;
                chooseNextAttack(boss, state);
            }
        }
    }
}

fn chooseNextAttack(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    var allowedAttacks: [4]?DragonActionData = .{ .{ .bodyStomp = .{} }, null, null, null };
    var allowedAttacksCount: usize = 1;
    if (data.phase == .phase2) {
        const hpPerCent: f32 = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
        if (hpPerCent > PHASE_3_TRANSITION_PER_CENT) {
            allowedAttacks[allowedAttacksCount] = .{ .wingBlast = .{} };
            allowedAttacksCount += 1;
            if (data.fireAbilitiesSinceLastWingBlast < 1) {
                allowedAttacks[allowedAttacksCount] = .{ .fireBreath = .{} };
                allowedAttacksCount += 1;
            }
        }
    }
    if (data.phase == .phase3) {
        if (data.fireAbilitiesSinceLastWingBlast < 2) {
            allowedAttacks[allowedAttacksCount] = .{ .fireBreath = .{} };
            allowedAttacksCount += 1;
        } else {
            allowedAttacks[allowedAttacksCount] = .{ .wingBlast = .{} };
            allowedAttacksCount += 1;
        }
        allowedAttacks[allowedAttacksCount] = .{ .tailAttack = .{} };
        allowedAttacksCount += 1;
    }
    const randomIndex = state.seededRandom.random().intRangeLessThan(usize, 0, allowedAttacksCount);
    setAction(allowedAttacks[randomIndex].?, boss);
}

fn setAction(action: DragonActionData, boss: *bossZig.Boss) void {
    boss.typeData.dragon.action = action;
    scaleAttackForNewGamePlus(boss);
}

fn scaleAttackForNewGamePlus(boss: *bossZig.Boss) void {
    if (boss.typeData.dragon.newGamePlus == 0) return;
    switch (boss.typeData.dragon.action) {
        .bodyStomp => |*data| {
            data.delay = @divFloor(data.delay, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
        },
        .landingStomp => |*data| {
            data.delay = @divFloor(data.delay, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
        },
        .wingBlast => |*data| {
            data.firstMoveTickDelay = @divFloor(data.firstMoveTickDelay, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
            data.moveInterval = @divFloor(data.moveInterval, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
            data.maxMoveTicks += @min(50, (boss.typeData.dragon.newGamePlus + 1) * 5);
        },
        .fireBreath => |*data| {
            data.firstFireSpitDelay = @divFloor(data.firstFireSpitDelay, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
            data.spitDuration += @intCast(boss.typeData.dragon.newGamePlus * 500);
        },
        .tailAttack => |*data| {
            data.tailAttackDelay = @divFloor(data.tailAttackDelay, @as(i32, @intCast(boss.typeData.dragon.newGamePlus + 1)));
        },
        else => {},
    }
}

fn moveBossTick(boss: *bossZig.Boss, targetPos: main.Position, passedTime: i64, speed: f32) bool {
    const data = &boss.typeData.dragon;
    const direction = main.calculateDirection(boss.position, targetPos);
    data.direction = direction;
    const distance: f32 = DEFAULT_FLYING_SPEED * @as(f32, @floatFromInt(passedTime));
    boss.position = main.moveByDirectionAndDistance(boss.position, direction, distance);
    if (main.calculateDistance(boss.position, targetPos) <= speed * 16) {
        boss.position = targetPos;
        return true;
    }
    return false;
}

fn tickTransitionFlyingPhase(flyingData: *TransitionFlyingData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (!flyingData.cameraDone) {
        if (flyingData.moveCameraToDefaultTime == null) {
            if (flyingData.keepCameraUntilTime == null) {
                flyingData.keepCameraUntilTime = state.gameTime + FLYING_TRANSITION_CAMERA_WAIT_TIME;
                flyingData.targetPlayerIndex = playerZig.getRandomAlivePlayerIndex(state);
                state.camera.position.y = FLYING_TRANSITION_CAMERA_OFFSET_Y;
                data.inAirHeight -= FLYING_TRANSITION_CAMERA_OFFSET_Y;
                for (state.mapData.paintData.backClouds[0..]) |*cloud| {
                    cloud.position.y += FLYING_TRANSITION_CAMERA_OFFSET_Y;
                }
                for (state.players.items) |*player| {
                    player.inAirHeight -= FLYING_TRANSITION_CAMERA_OFFSET_Y;
                    if (player.startedFallingState != null) {
                        player.startedFallingState = state.gameTime + 3000;
                    }
                }
                for (state.enemyData.enemyObjects.items) |*object| {
                    if (object.typeData == .fire) {
                        if (object.typeData.fire.flyToPosition == null) object.typeData.fire.flyToPosition = object.position;
                        object.typeData.fire.inAirHeight -= FLYING_TRANSITION_CAMERA_OFFSET_Y;
                    }
                }
                state.mapData.paintData.frontCloud.position.y += FLYING_TRANSITION_CAMERA_OFFSET_Y;
            } else if (flyingData.keepCameraUntilTime.? <= state.gameTime) {
                flyingData.moveCameraToDefaultTime = state.gameTime + FLYING_TRANSITION_CAMERA_MOVE_DURATION;
            }
        } else {
            const movePerCent: f32 = @max(0, @as(f32, @floatFromInt(flyingData.moveCameraToDefaultTime.? - state.gameTime)) / FLYING_TRANSITION_CAMERA_MOVE_DURATION);
            state.camera.position.y = FLYING_TRANSITION_CAMERA_OFFSET_Y * movePerCent;
            if (movePerCent == 0) {
                flyingData.cameraDone = true;
            }
        }
    }
    if (flyingData.dragonFlyPositionIndex < FLYING_TRANSITION_DRAGON_POSITIONS.len) {
        if (flyingData.moveCameraToDefaultTime != null) {
            if (data.inAirHeight > DEFAULT_FYLING_HEIGHT) {
                data.inAirHeight -= DEFAULT_FLYING_SPEED * @as(f32, @floatFromInt(passedTime));
            }
            var currentTargetPos = FLYING_TRANSITION_DRAGON_POSITIONS[flyingData.dragonFlyPositionIndex];
            if (flyingData.targetPlayerIndex) |randomPlayerIndex| {
                switch (flyingData.dragonFlyPositionIndex) {
                    0 => {
                        const fMapRadius = @as(f32, @floatFromInt(state.mapData.tileRadiusHeight * main.TILESIZE));
                        const offsetY: f32 = @max(@min(fMapRadius, state.players.items[randomPlayerIndex].position.y), -fMapRadius);
                        currentTargetPos.y = offsetY;
                    },
                    1 => currentTargetPos.y = boss.position.y,
                    2 => {
                        const fMapRadius = @as(f32, @floatFromInt(state.mapData.tileRadiusWidth * main.TILESIZE));
                        const offsetX: f32 = @max(@min(fMapRadius, state.players.items[randomPlayerIndex].position.x), -fMapRadius);
                        currentTargetPos.x = offsetX;
                    },
                    3 => currentTargetPos.x = boss.position.x,
                    else => {},
                }
            } else {
                flyingData.targetPlayerIndex = playerZig.getRandomAlivePlayerIndex(state);
            }

            if (moveBossTick(boss, currentTargetPos, passedTime, DEFAULT_FLYING_SPEED)) {
                flyingData.dragonFlyPositionIndex += 1;
                if (flyingData.dragonFlyPositionIndex == 1 or flyingData.dragonFlyPositionIndex == 3) {
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BREATH_IN, 0, 1);
                    if (flyingData.dragonFlyPositionIndex == 1) {
                        flyingData.fireSpawnTile = @intCast(state.mapData.tileRadiusWidth);
                    } else {
                        flyingData.fireSpawnTile = @intCast(state.mapData.tileRadiusHeight);
                    }
                }
            }
            const bossTilePos = main.gamePositionToTilePosition(boss.position);
            if (flyingData.dragonFlyPositionIndex == 1) {
                if (flyingData.fireSpawnTile.? >= bossTilePos.x and -@as(i32, @intCast(state.mapData.tileRadiusWidth)) <= flyingData.fireSpawnTile.?) {
                    flyingData.fireSpawnTile.? -= 1;
                    const flyToPosition = main.tilePositionToGamePosition(main.gamePositionToTilePosition(boss.position));
                    const fireSpawn: main.Position = .{ .x = boss.position.x, .y = boss.position.y };
                    try enemyObjectFireZig.spawnEternalFire(fireSpawn, flyToPosition, data.inAirHeight, state);
                    if (data.soundData.lastFireBreathTime == null or data.soundData.lastFireBreathTime.? + 650 < state.gameTime) {
                        try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_FIRE_BREATH, 0, 1);
                        data.soundData.lastFireBreathTime = state.gameTime;
                    }
                    if (data.phase == .phase3) {
                        var secondFireFlyToPos: main.Position = flyToPosition;
                        if (boss.position.y < 0) {
                            secondFireFlyToPos.y += main.TILESIZE;
                        } else {
                            secondFireFlyToPos.y -= main.TILESIZE;
                        }
                        try enemyObjectFireZig.spawnEternalFire(fireSpawn, secondFireFlyToPos, data.inAirHeight, state);
                    }
                }
            }
            if (flyingData.dragonFlyPositionIndex == 3) {
                if (flyingData.fireSpawnTile.? >= bossTilePos.y and -@as(i32, @intCast(state.mapData.tileRadiusHeight)) <= flyingData.fireSpawnTile.?) {
                    flyingData.fireSpawnTile.? -= 1;
                    const flyToPosition = main.tilePositionToGamePosition(main.gamePositionToTilePosition(boss.position));
                    const fireSpawn: main.Position = .{ .x = boss.position.x, .y = boss.position.y };
                    try enemyObjectFireZig.spawnEternalFire(fireSpawn, flyToPosition, data.inAirHeight, state);
                    if (data.soundData.lastFireBreathTime == null or data.soundData.lastFireBreathTime.? + 650 < state.gameTime) {
                        try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_FIRE_BREATH, 0, 1);
                        data.soundData.lastFireBreathTime = state.gameTime;
                    }
                    if (data.phase == .phase3) {
                        var secondFireFlyToPos: main.Position = flyToPosition;
                        if (boss.position.x < 0) {
                            secondFireFlyToPos.x += main.TILESIZE;
                        } else {
                            secondFireFlyToPos.x -= main.TILESIZE;
                        }
                        try enemyObjectFireZig.spawnEternalFire(fireSpawn, secondFireFlyToPos, data.inAirHeight, state);
                    }
                }
            }
        }
    } else {
        data.paint.standingPerCent = 1;
        data.action = .{ .landing = .{ .targetPos = .{ .x = 0, .y = 0 } } };
        data.fireAbilitiesSinceLastWingBlast += 1;
    }
}

fn adjustFeetToTiles(boss: *bossZig.Boss, passedTime: i64) void {
    const data = &boss.typeData.dragon;
    for (0..4) |index| {
        if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
            data.feetOffset[index] = .{ .x = 0, .y = 0 };
            continue;
        }
        var moveFeet = true;
        if (data.movingFeetPair1) {
            if (index != 0 and index != 3) {
                moveFeet = false;
            }
        } else {
            if (index == 0 or index == 3) {
                moveFeet = false;
            }
        }
        if (moveFeet) {
            const shouldBeOffset = getFootShouldBeOffset(index, boss);
            const direction = main.calculateDirection(data.feetOffset[index], shouldBeOffset);
            const moveDistance: f32 = @as(f32, @floatFromInt(passedTime)) * data.moveSpeed * 2;
            data.feetOffset[index] = main.moveByDirectionAndDistance(data.feetOffset[index], direction, moveDistance);
            const distance = main.calculateDistance(shouldBeOffset, data.feetOffset[index]);
            if (distance < 2) {
                data.feetOffset[index] = shouldBeOffset;
                data.movingFeetPair1 = !data.movingFeetPair1;
            }
        } else {
            data.feetOffset[index] = getFootToCurrentTileOffset(index, boss);
        }
    }
}

fn getFootShouldBeOffset(index: usize, boss: *bossZig.Boss) main.Position {
    const data = &boss.typeData.dragon;
    if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
        return .{ .x = 0, .y = 0 };
    }
    const defaultFootOffset = DEFAULT_FEET_OFFSET[index];
    const rotatedOffset = main.rotateAroundPoint(defaultFootOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const footPosition: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
    const tilePos = main.gamePositionToTilePosition(footPosition);
    const alignedToTilePos = main.tilePositionToGamePosition(tilePos);
    const alignedOffset: main.Position = .{ .x = alignedToTilePos.x - boss.position.x, .y = alignedToTilePos.y - boss.position.y };
    const unrotatedDefaultOffset = main.rotateAroundPoint(alignedOffset, .{ .x = 0, .y = 0 }, -data.paint.rotation);
    return .{ .x = unrotatedDefaultOffset.x - defaultFootOffset.x, .y = unrotatedDefaultOffset.y - defaultFootOffset.y };
}

fn getFootToCurrentTileOffset(index: usize, boss: *bossZig.Boss) main.Position {
    const data = &boss.typeData.dragon;
    if (data.inAirHeight > 10 or (index >= 2 and data.paint.standingPerCent > 0.2)) {
        return .{ .x = 0, .y = 0 };
    }
    const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
    const rotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const footPosition: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
    const tilePos = main.gamePositionToTilePosition(footPosition);
    const alignedToTilePos = main.tilePositionToGamePosition(tilePos);
    const alignedOffset: main.Position = .{ .x = alignedToTilePos.x - boss.position.x, .y = alignedToTilePos.y - boss.position.y };
    const unrotatedToTileOffset = main.rotateAroundPoint(alignedOffset, .{ .x = 0, .y = 0 }, -data.paint.rotation);
    return .{ .x = unrotatedToTileOffset.x - DEFAULT_FEET_OFFSET[index].x, .y = unrotatedToTileOffset.y - DEFAULT_FEET_OFFSET[index].y };
}

fn standUpOrDownTick(boss: *bossZig.Boss, up: bool, passedTime: i64, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    const ngpFactor: f32 = 1 + @as(f32, @floatFromInt(state.newGamePlus)) / 3.0;
    const distanceUp: f32 = STAND_UP_SPEED * @as(f32, @floatFromInt(passedTime)) * ngpFactor;
    if (up) {
        data.paint.standingPerCent = @min(1, data.paint.standingPerCent + distanceUp);
    } else {
        data.paint.standingPerCent = @max(0, data.paint.standingPerCent - distanceUp);
    }
}

fn tickBodyStomp(stompData: *BodyStompData, boss: *bossZig.Boss, passedTime: i64, state: *main.GameState) !void {
    const data = &boss.typeData.dragon;
    if (stompData.stompTime == null and data.paint.standingPerCent < 1) {
        standUpOrDownTick(boss, true, passedTime, state);
    } else if (stompData.stompTime == null) {
        if (playerZig.getClosestPlayer(boss.position, state).player) |targetPlayer| {
            if (stompData.latestStompStartTime == null) {
                stompData.latestStompStartTime = state.gameTime + 5000;
            }
            if (stompData.latestStompStartTime.? < state.gameTime) {
                stompData.stompTime = state.gameTime + stompData.delay;
            } else {
                const direction = main.calculateDirection(boss.position, targetPlayer.position);
                setDirection(boss, direction);
                const distance = main.calculateDistance(boss.position, targetPlayer.position);
                if (distance > 40) {
                    const moveDistance: f32 = data.moveSpeed * @as(f32, @floatFromInt(passedTime));
                    boss.position = main.moveByDirectionAndDistance(boss.position, data.direction, moveDistance);
                } else {
                    stompData.stompTime = state.gameTime + stompData.delay;
                }
            }
        }
    } else {
        const stompTime = stompData.stompTime.?;
        const stompPerCent: f32 = 1 - @max(0, @as(f32, @floatFromInt(stompTime - state.gameTime)) / @as(f32, @floatFromInt(stompData.delay)));

        const stompStartPerCent = 0.5;
        if (stompPerCent > stompStartPerCent and passedTime > 0) {
            data.paint.standingPerCent = @sqrt((1 - stompPerCent) / (1 - stompStartPerCent));
        }
        if (stompTime <= state.gameTime) {
            const hpPerCent: f32 = @as(f32, @floatFromInt(boss.hp)) / @as(f32, @floatFromInt(boss.maxHp));
            if (data.phase == .phase1 and hpPerCent < PHASE_2_TRANSITION_PER_CENT) {
                data.action = .{ .transitionFlyingPhase = .{} };
                data.phase = .phase2;
                try cutTilesForGroundBreakingEffect(FLYING_TRANSITION_CAMERA_OFFSET_Y, state);
            } else if (data.phase == .phase2 and hpPerCent < PHASE_3_TRANSITION_PER_CENT) {
                data.action = .{ .transitionFlyingPhase = .{} };
                data.phase = .phase3;
                try cutTilesForGroundBreakingEffect(FLYING_TRANSITION_CAMERA_OFFSET_Y, state);
            } else {
                chooseNextAttack(boss, state);
            }
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_STOMP_INDICIES[0..], 0, 1);
            const attackTileCenter = main.gamePositionToTilePosition(.{ .x = boss.position.x, .y = boss.position.y });
            const damageTileRectangle: main.TileRectangle = .{
                .pos = .{ .x = attackTileCenter.x - BODY_STOMP_AREA_RADIUS_X, .y = attackTileCenter.y - BODY_STOMP_AREA_RADIUS_Y },
                .width = BODY_STOMP_AREA_RADIUS_X * 2 + 1,
                .height = BODY_STOMP_AREA_RADIUS_Y * 2 + 1,
            };
            for (state.players.items) |*player| {
                const playerTile = main.gamePositionToTilePosition(player.position);
                if (main.isTilePositionInTileRectangle(playerTile, damageTileRectangle)) {
                    try playerZig.playerHit(player, state);
                }
            }
            data.paint.visualizeAttackPosition = state.gameTime + ATTACK_VISAULIZE_DURATION;
            data.paint.lastAttackRectangle = .{
                .pos = .{ .x = @as(f32, @floatFromInt(damageTileRectangle.pos.x)) * main.TILESIZE, .y = @as(f32, @floatFromInt(damageTileRectangle.pos.y)) * main.TILESIZE },
                .width = @as(f32, @floatFromInt(damageTileRectangle.width)) * main.TILESIZE,
                .height = @as(f32, @floatFromInt(damageTileRectangle.height)) * main.TILESIZE,
            };
        }
    }
}

pub fn cutTilesForGroundBreakingEffect(offsetY: f32, state: *main.GameState) !void {
    const mapGridWidth = state.mapData.tileRadiusWidth * 2 + 1;
    const mapGridHeight = state.mapData.tileRadiusHeight * 2 + 1;
    const fMapTileRadiusWidth: f32 = @floatFromInt(state.mapData.tileRadiusWidth);
    const fMapTileRadiusHeight: f32 = @floatFromInt(state.mapData.tileRadiusHeight);
    for (0..mapGridWidth) |i| {
        const x: f32 = (@as(f32, @floatFromInt(i)) - fMapTileRadiusWidth) * main.TILESIZE;
        for (0..mapGridHeight) |j| {
            const y: f32 = (@as(f32, @floatFromInt(j)) - fMapTileRadiusHeight) * main.TILESIZE;
            try state.spriteCutAnimations.append(.{
                .deathTime = state.gameTime,
                .position = .{ .x = x, .y = y + offsetY },
                .cutAngle = 0,
                .force = -1,
                .colorOrImageIndex = .{ .color = main.COLOR_TILE_GREEN },
            });
        }
    }
}

fn isBossHit(boss: *bossZig.Boss, player: *playerZig.Player, hitArea: main.TileRectangle, cutRotation: f32, hitDirection: u8, state: *main.GameState) !bool {
    _ = hitDirection;
    const data = &boss.typeData.dragon;
    if (data.inAirHeight < 5) {
        for (data.feetOffset, 0..) |footOffset, footIndex| {
            const footOffset2: main.Position = .{ .x = footOffset.x + DEFAULT_FEET_OFFSET[footIndex].x, .y = footOffset.y + DEFAULT_FEET_OFFSET[footIndex].y };
            const rotatedOffset = main.rotateAroundPoint(footOffset2, .{ .x = 0, .y = 0 }, data.paint.rotation);
            const footPos: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y };
            const footTile = main.gamePositionToTilePosition(footPos);
            if (footIndex >= 2 and data.paint.standingPerCent > 0.2) {
                continue;
            }
            if (main.isTilePositionInTileRectangle(footTile, hitArea)) {
                boss.hp -|= playerZig.getPlayerDamage(player);
                if (boss.hp <= 0) {
                    try bossDeathCutSprites(boss, cutRotation, state);
                }
                return true;
            }
        }
    }
    return false;
}

fn bossDeathCutSprites(boss: *bossZig.Boss, cutRotation: f32, state: *main.GameState) !void {
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER1 },
        .cutAngle = cutRotation,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = boss.position,
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER2 },
        .cutAngle = cutRotation,
        .deathTime = state.gameTime,
        .force = 0.9,
        .position = boss.position,
    });
    try state.spriteCutAnimations.append(.{
        .colorOrImageIndex = .{ .imageIndex = imageZig.IMAGE_BOSS_DRAGON_BODY_TOP },
        .cutAngle = cutRotation,
        .deathTime = state.gameTime,
        .force = 1.5,
        .position = boss.position,
    });
}

fn setDirection(boss: *bossZig.Boss, newDirection: f32) void {
    const data = &boss.typeData.dragon;
    const rotationPivot: main.Position = .{
        .x = 0,
        .y = -main.TILESIZE * data.paint.standingPerCent,
    };
    const oldOffset = main.rotateAroundPoint(.{ .x = 0, .y = 0 }, rotationPivot, data.direction - std.math.pi / 2.0);
    const newOffset = main.rotateAroundPoint(.{ .x = 0, .y = 0 }, rotationPivot, newDirection - std.math.pi / 2.0);
    boss.position.x = boss.position.x - oldOffset.x + newOffset.x;
    boss.position.y = boss.position.y - oldOffset.y + newOffset.y;
    data.direction = newDirection;
    data.paint.rotation = data.direction - std.math.pi / 2.0;
}

fn setupVerticesGround(boss: *bossZig.Boss, state: *main.GameState) !void {
    const data = boss.typeData.dragon;
    if (data.paint.visualizeAttackPosition) |time| {
        if (time > state.gameTime) {
            const alphaPerCent: f32 = @as(f32, @floatFromInt(time - state.gameTime)) / @as(f32, @floatFromInt(ATTACK_VISAULIZE_DURATION));
            paintVulkanZig.verticesForGameRectangle(data.paint.lastAttackRectangle, .{ 0.8, 0, 0, alphaPerCent }, state);
        }
    }
    switch (data.action) {
        .landingStomp => |stompData| {
            if (stompData.stompTime) |stompTime| {
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(stompTime - state.gameTime)) / @as(f32, @floatFromInt(stompData.delay))));
                const sizeX: usize = @intCast(LANDING_STOMP_AREA_RADIUS_X * 2 + 1);
                const sizeY: usize = @intCast(LANDING_STOMP_AREA_RADIUS_Y * 2 + 1);
                for (0..sizeX) |i| {
                    const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - LANDING_STOMP_AREA_RADIUS_X)) * main.TILESIZE + LANDING_STOMP_AREA_OFFSET.x;
                    for (0..sizeY) |j| {
                        const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - LANDING_STOMP_AREA_RADIUS_Y)) * main.TILESIZE + LANDING_STOMP_AREA_OFFSET.y;
                        enemyVulkanZig.addWarningTileSprites(.{
                            .x = boss.position.x + offsetX,
                            .y = boss.position.y + offsetY,
                        }, fillPerCent, state);
                    }
                }
            }
        },
        .bodyStomp => |stompData| {
            if (stompData.stompTime) |stompTime| {
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(stompTime - state.gameTime)) / @as(f32, @floatFromInt(stompData.delay))));
                const sizeX: usize = @intCast(BODY_STOMP_AREA_RADIUS_X * 2 + 1);
                const sizeY: usize = @intCast(BODY_STOMP_AREA_RADIUS_Y * 2 + 1);
                for (0..sizeX) |i| {
                    const offsetX: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(i)) - BODY_STOMP_AREA_RADIUS_X)) * main.TILESIZE;
                    for (0..sizeY) |j| {
                        const offsetY: f32 = @as(f32, @floatFromInt(@as(i32, @intCast(j)) - BODY_STOMP_AREA_RADIUS_Y)) * main.TILESIZE;
                        const tilePos: main.TilePosition = main.gamePositionToTilePosition(.{
                            .x = boss.position.x + offsetX,
                            .y = boss.position.y + offsetY,
                        });
                        enemyVulkanZig.addWarningTileSprites(.{
                            .x = @floatFromInt(tilePos.x * main.TILESIZE),
                            .y = @floatFromInt(tilePos.y * main.TILESIZE),
                        }, fillPerCent, state);
                    }
                }
            }
        },
        .wingBlast => |wingBlastData| {
            if (wingBlastData.nextMoveTickTime) |nextMoveTime| {
                const rotation: f32 = @as(f32, @floatFromInt(wingBlastData.direction.?)) * std.math.pi / 2.0;
                const duration = if (wingBlastData.moveTickCount == 0) wingBlastData.firstMoveTickDelay else wingBlastData.moveInterval;
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(nextMoveTime - state.gameTime)) / @as(f32, @floatFromInt(duration))));
                const stepDirection = movePieceZig.getStepDirection(wingBlastData.direction.?);
                for (state.players.items) |player| {
                    if (player.isDead) continue;
                    enemyVulkanZig.addRedArrowTileSprites(.{
                        .x = player.position.x + stepDirection.x * main.TILESIZE,
                        .y = player.position.y + stepDirection.y * main.TILESIZE,
                    }, fillPerCent, rotation, state);
                }
            }
        },
        .tailAttack => |tailAttackData| {
            if (tailAttackData.tailAttackHitTime) |hitTime| {
                const fillPerCent: f32 = 1 - @min(1, @max(0, @as(f32, @floatFromInt(hitTime - state.gameTime)) / @as(f32, @floatFromInt(tailAttackData.tailAttackDelay))));
                for (data.attackTiles.items) |attackPos| {
                    enemyVulkanZig.addWarningTileSprites(.{
                        .x = @floatFromInt(attackPos.x * main.TILESIZE),
                        .y = @floatFromInt(attackPos.y * main.TILESIZE),
                    }, fillPerCent, state);
                }
            }
        },
        else => {},
    }
}

fn setupVertices(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    data.paint.rotation = data.direction - std.math.pi / 2.0;
    paintShadow(boss, state);
    paintDragonBackFeet(boss, state);
    if (data.paint.standingPerCent < 0.5) {
        paintDragonFrontFeet(boss, state);
    }
    paintDragonTail(boss, state);
    if (data.paint.standingPerCent > 0.5) paintDragonWings(boss, state);
    paintDragonBody(boss, state);
    if (data.paint.standingPerCent <= 0.5) paintDragonWings(boss, state);

    if (data.paint.standingPerCent >= 0.5) {
        paintDragonFrontFeet(boss, state);
    }
    paintDragonHead(boss, state);
}

fn paintShadow(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    if (data.inAirHeight > 1) {
        paintVulkanZig.verticesForComplexSprite(
            .{
                .x = boss.position.x,
                .y = boss.position.y + 5 - data.paint.standingPerCent * 20,
            },
            imageZig.IMAGE_SHADOW,
            4,
            4,
            0.75,
            0,
            false,
            false,
            state,
        );
    }
}

fn paintDragonHead(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const headOffset: main.Position = .{
        .x = 0,
        .y = 45 - 160 * data.paint.standingPerCent,
    };
    const rotatedOffset = main.rotateAroundPoint(headOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const headPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
    };
    paintVulkanZig.verticesForComplexSpriteWithRotate(headPosition, imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER1, data.paint.rotation, data.paint.alpha, state);
    const scaleY = 1 - (data.paint.mouthOpenPerCent * 0.5);
    paintVulkanZig.verticesForComplexSprite(
        headPosition,
        imageZig.IMAGE_BOSS_DRAGON_HEAD_LAYER2,
        1,
        scaleY,
        data.paint.alpha,
        data.paint.rotation,
        false,
        false,
        state,
    );
}

fn paintDragonBackFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (0..2) |index| {
        const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
        const rotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
        const footPos: main.Position = .{ .x = boss.position.x + rotatedOffset.x, .y = boss.position.y + rotatedOffset.y - data.inAirHeight };
        paintVulkanZig.verticesForComplexSpriteWithRotate(footPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, data.paint.rotation, 1, state);
    }
}

fn paintDragonFrontFeet(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    for (2..4) |index| {
        const footOffset: main.Position = .{ .x = data.feetOffset[index].x + DEFAULT_FEET_OFFSET[index].x, .y = data.feetOffset[index].y + DEFAULT_FEET_OFFSET[index].y };
        const bodyRotationOffset: main.Position = .{
            .x = 0,
            .y = -100 * data.paint.standingPerCent,
        };
        const bodyRotatedOffset = main.rotateAroundPoint(bodyRotationOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
        const feetRotatedOffset = main.rotateAroundPoint(footOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);

        const footInAirPos: main.Position = .{
            .x = boss.position.x + feetRotatedOffset.x + bodyRotatedOffset.x,
            .y = boss.position.y + feetRotatedOffset.y + bodyRotatedOffset.y - data.inAirHeight,
        };
        const alpha = if (data.paint.standingPerCent < 0.1) 1 else data.paint.alpha;
        paintVulkanZig.verticesForComplexSpriteWithRotate(footInAirPos, imageZig.IMAGE_BOSS_DRAGON_FOOT, data.paint.rotation, alpha, state);
    }
}

fn paintDragonTail(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const tailOffset: main.Position = .{
        .x = 0,
        .y = -70,
    };
    const rotatedOffset = main.rotateAroundPoint(tailOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const tailPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
    };
    paintVulkanZig.addTiranglesForSpriteWithBend(
        tailPosition,
        imageZig.getImageCenter(imageZig.IMAGE_BOSS_DRAGON_TAIL),
        imageZig.IMAGE_BOSS_DRAGON_TAIL,
        data.paint.rotation,
        null,
        .{ .x = imageZig.IMAGE_DATA[imageZig.IMAGE_BOSS_DRAGON_TAIL].scale, .y = imageZig.IMAGE_DATA[imageZig.IMAGE_BOSS_DRAGON_TAIL].scale },
        data.paint.tailUpPerCent * 1.75,
        false,
        data.paint.alpha,
        state,
    );
}

fn paintDragonWings(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = &boss.typeData.dragon;
    const scaleY = 0.1 + @abs(data.paint.standingPerCent - 0.5) * 2 * 0.9;
    var scaleX: f32 = 1;
    var wingsFlap: f32 = 0;
    if (data.inAirHeight > 0 and data.paint.wingsFlapStarted == null) {
        data.paint.wingsFlapStarted = state.gameTime;
    }
    if (data.paint.wingsFlapStarted) |time| {
        wingsFlap = @sin(@as(f32, @floatFromInt((state.gameTime - time))) * data.paint.wingFlapSpeedFactor / 200);
        scaleX += (wingsFlap / 2);
        if (data.inAirHeight < 1 and data.paint.stopWings and @abs(wingsFlap) < 0.1) data.paint.wingsFlapStarted = null;
    }
    const imageData = imageZig.IMAGE_DATA[imageZig.IMAGE_BOSS_DRAGON_WING];
    const imageToGameSizeFactor: f32 = imageData.scale / imageZig.IMAGE_TO_GAME_SIZE;
    const wingsFlapOffset = @as(f32, @floatFromInt(imageData.width)) * imageToGameSizeFactor * (1 - scaleX) / 2;

    const wingLeftOffset: main.Position = .{
        .x = 50 - wingsFlapOffset,
        .y = 10 - 90 * data.paint.standingPerCent,
    };
    const wingRightOffset: main.Position = .{
        .x = -50 + wingsFlapOffset,
        .y = 10 - 90 * data.paint.standingPerCent,
    };
    const rotatedLeftOffset = main.rotateAroundPoint(wingLeftOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const rotatedRightOffset = main.rotateAroundPoint(wingRightOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const wingLeftPosition: main.Position = .{
        .x = boss.position.x + rotatedLeftOffset.x,
        .y = boss.position.y + rotatedLeftOffset.y - data.inAirHeight,
    };
    const wingRightPosition: main.Position = .{
        .x = boss.position.x + rotatedRightOffset.x,
        .y = boss.position.y + rotatedRightOffset.y - data.inAirHeight,
    };

    if (data.paint.standingPerCent > 0.5) {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, data.paint.alpha, data.paint.rotation, true, false, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, data.paint.alpha, data.paint.rotation, false, false, state);
    } else {
        paintVulkanZig.verticesForComplexSprite(wingLeftPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, data.paint.alpha, data.paint.rotation, true, true, state);
        paintVulkanZig.verticesForComplexSprite(wingRightPosition, imageZig.IMAGE_BOSS_DRAGON_WING, scaleX, scaleY, data.paint.alpha, data.paint.rotation, false, true, state);
    }
}

fn paintDragonBody(boss: *bossZig.Boss, state: *main.GameState) void {
    const data = boss.typeData.dragon;
    const bodyOffset: main.Position = .{
        .x = 0,
        .y = -60 * data.paint.standingPerCent,
    };
    const rotatedOffset = main.rotateAroundPoint(bodyOffset, .{ .x = 0, .y = 0 }, data.paint.rotation);
    const bodyPosition: main.Position = .{
        .x = boss.position.x + rotatedOffset.x,
        .y = boss.position.y + rotatedOffset.y - data.inAirHeight,
    };
    const scaleY = 0.5 + @abs(data.paint.standingPerCent - 0.5);
    paintVulkanZig.verticesForComplexSpriteWithCut(
        bodyPosition,
        imageZig.IMAGE_BOSS_DRAGON_BODY_BOTTOM,
        1 - data.paint.standingPerCent,
        1,
        data.paint.alpha,
        data.paint.rotation,
        1,
        scaleY,
        state,
    );
    paintVulkanZig.verticesForComplexSpriteWithCut(
        bodyPosition,
        imageZig.IMAGE_BOSS_DRAGON_BODY_TOP,
        0,
        1 - data.paint.standingPerCent,
        data.paint.alpha,
        data.paint.rotation,
        1,
        scaleY,
        state,
    );
}
