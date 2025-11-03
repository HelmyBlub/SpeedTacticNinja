const std = @import("std");
const windowSdlZig = @import("windowSdl.zig");
const initVulkanZig = @import("vulkan/initVulkan.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const movePieceZig = @import("movePiece.zig");
const ninjaDogVulkanZig = @import("vulkan/ninjaDogVulkan.zig");
const soundMixerZig = @import("soundMixer.zig");
const enemyZig = @import("enemy/enemy.zig");
const enemyObjectZig = @import("enemy/enemyObject.zig");
const enemyObjectFallDownZig = @import("enemy/enemyObjectFallDown.zig");
const shopZig = @import("shop.zig");
const bossZig = @import("boss/boss.zig");
const imageZig = @import("image.zig");
const mapTileZig = @import("mapTile.zig");
const equipmentZig = @import("equipment.zig");
const statsZig = @import("stats.zig");
const verifyMapZig = @import("verifyMap.zig");
const inputZig = @import("input.zig");
const playerZig = @import("player.zig");
const bossDragonZig = @import("boss/bossDragon.zig");
const settingsMenuVulkanZig = @import("vulkan/settingsMenuVulkan.zig");
const fileSaveZig = @import("fileSave.zig");
const steamZig = @import("steam.zig");
const achievementZig = @import("achievement.zig");
const modeSelectZig = @import("modeSelect.zig");
const autoTestZig = @import("autoTest.zig");
const onStartErrorDisplayZig = @import("onStartErrorDisplay.zig");

pub const GamePhase = enum {
    modeSelect,
    combat,
    shopping,
    boss,
    finished,
};
pub const COLOR_TILE_GREEN: [4]f32 = colorConv(0.533, 0.80, 0.231);
pub const COLOR_SKY_BLUE: [4]f32 = colorConv(0.529, 0.808, 0.922);
pub const COLOR_STONE_WALL: [4]f32 = colorConv(0.573, 0.522, 0.451);
pub const LEVEL_COUNT = 50;
const CREDITS_START_OFFSET_PLAYER_Y: comptime_int = -@as(comptime_int, @intCast(CREDITS_TEXTS.len)) * TILESIZE * 5;
pub const CREDITS_TEXTS = [_][]const u8{
    "You Win",
    "", //total time displayed here
    "",
    "",
    "Credits:",
    "",
    "Everything done by:",
    "Helmi Blub",
    "",
    "Thanks for playing",
};

pub const UPDATES_PER_SECOND = 200;
pub const TICK_INTERVAL_MICRO_SECONDS = 1_000_000 / UPDATES_PER_SECOND;
const TICK_INTERVAL_MS = TICK_INTERVAL_MICRO_SECONDS / 1000;
pub const TILESIZE = 20;
pub const GameState = struct {
    vkState: initVulkanZig.VkState = .{},
    allocator: std.mem.Allocator = undefined,
    camera: Camera = .{ .position = .{ .x = 0, .y = 0 }, .zoom = 1 },
    gameTime: i64 = 0,
    round: u32 = 1,
    level: u32 = 0,
    newGamePlus: u32 = 0,
    mapData: mapTileZig.MapData,
    suddenDeathTimeMs: i64 = 0,
    roundStartedTime: i64 = 0,
    bosses: std.ArrayList(bossZig.Boss) = undefined,
    enemyData: enemyZig.EnemyData = .{},
    spriteCutAnimations: std.ArrayList(CutSpriteAnimation) = undefined,
    mapObjects: std.ArrayList(MapObject) = undefined,
    players: std.ArrayList(playerZig.Player),
    playerTookDamageOnLevel: bool = false,
    soundMixer: ?soundMixerZig.SoundMixer = null,
    gameQuit: bool = false,
    gamePhase: GamePhase = .combat,
    shop: shopZig.ShopData,
    lastBossDefeatedTime: i64 = 0,
    statistics: statsZig.Statistics,
    suddenDeath: u32 = 0,
    gameOver: bool = false,
    gameOverRealTime: i64 = 0,
    verifyMapData: verifyMapZig.VerifyMapData = .{},
    continueData: ContinueData = .{},
    soundData: SoundData = .{},
    inputJoinData: inputZig.InputJoinData,
    tempStringBuffer: []u8,
    tutorialData: TutorialData = .{},
    gateOpenTime: ?i64 = null,
    uxData: GameUxData,
    lastAfkShootTime: ?i64 = null,
    timeFreezed: ?i64 = null,
    timeFreezeOnHit: bool = false,
    pauseInputTime: ?i64 = null,
    paused: bool = false,
    vulkanMousePosition: ?Position = null,
    highestNewGameDifficultyBeaten: i32 = -1,
    highestLevelBeaten: u32 = 0,
    steam: ?steamZig.SteamData = null,
    achievements: std.EnumArray(achievementZig.AchievementsEnum, achievementZig.AchievementData) = achievementZig.ACHIEVEMENTS,
    modeSelect: modeSelectZig.ModeSelectData = .{},
    seededRandom: std.Random.Xoshiro256,
    autoTest: autoTestZig.AutoTestData,
    windowData: windowSdlZig.WindowData = .{},
    onStartError: onStartErrorDisplayZig.OnStartErrorDisplay,
    config: GameConfig = .{},
};

pub const GameConfig = struct {
    roundToReachForNextLevel: usize = 5,
    bonusTimePerRoundFinished: i32 = 5000,
    minimalTimePerRequiredRounds: i32 = 60_000,
    playerImmunityFrames: i64 = 1000,
    maxEnemyLevelStartCount: u32 = 6,
    minEnemyLevelStartCount: u32 = 1,
    moneyGainMultiply: f32 = 1.0,
    shopMinBuyOptions: u32 = 3,
    additionalFreeContinues: u32 = 0,
    playerMovePieceRandom: u32 = 3,
};

pub const GameUxData = struct {
    holdDefaultDuration: i32 = 1_500,
    continueButtonHoldStart: ?i64 = null,
    restartButtonHoldStart: ?i64 = null,
    quitButtonHoldStart: ?i64 = null,
    gameVulkanArea: Rectangle = .{ .pos = .{ .x = -0.75, .y = -0.75 }, .width = 1.5, .height = 1.5 },
    displayBossAcedUntilTime: ?i64 = null,
    displayReceivedFreeContinue: ?i64 = null,
    creditsScrollStart: ?i64 = null,
    creditsFontSize: f32 = 120,
    creditsScrollSpeedSlowdown: f32 = 5000,
    settingsMenuUx: settingsMenuVulkanZig.SettingsUx = .{},
    timeChangeVisualization: ?i64 = null,
    timeChange: TimeChangeUnion = .{ .refresh = false },
    levelInfoRec: Rectangle = .{},
    roundInfoRec: Rectangle = .{},
    newGamePlusInfoRec: Rectangle = .{},
    enableInfoRectangles: bool = true,
    lastMouseInput: i64 = 0,
    achievementGained: std.ArrayList(achievementZig.AchievementGainedDisplayData),
    achievementGainedLastSoundTime: i64 = 0,
};

const TimeChangeUnion = union(enum) {
    refresh: bool,
    timeAdded: i32,
};

pub const TutorialData = struct {
    active: bool = true,
    firstKeyDownInput: ?i64 = null,
    playerFirstValidPieceSelection: ?i64 = null,
    playerFirstValidMove: bool = false,
};

pub const SoundData = struct {
    suddenDeathPlayed: bool = false,
    warningSoundPlayed: bool = false,
    tickSoundPlayedCounter: u32 = 0,
    gateOpenTime: ?i64 = null,
};

const ContinueData = struct {
    freeContinues: u32 = 0,
    bossesAced: u32 = 0,
    nextBossAceFreeContinue: u32 = 1,
    nextBossAceFreeContinueIncrease: u32 = 2,
    paidContinues: u32 = 0,
};

pub const MapObjectType = enum {
    kunai,
};

pub const MabObjectKunaiData = struct {
    direction: u8,
    speed: f32,
    deleteTime: i64,
};

pub const MapObjectTypeData = union(MapObjectType) {
    kunai: MabObjectKunaiData,
};

pub const MapObject = struct {
    position: Position,
    typeData: MapObjectTypeData,
};

pub const ColorOrImageIndex = enum {
    color,
    imageIndex,
};

pub const ColorOrImageIndexData = union(ColorOrImageIndex) {
    color: [4]f32,
    imageIndex: u8,
};

pub const CutSpriteAnimation = struct {
    position: Position,
    deathTime: i64,
    cutAngle: f32,
    force: f32,
    colorOrImageIndex: ColorOrImageIndexData,
    imageToGameScaleFactor: f32 = 1.0 / @as(f32, @floatFromInt(imageZig.IMAGE_TO_GAME_SIZE)) / 2.0,
};

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const TilePosition = struct {
    x: i32,
    y: i32,
};

pub const Camera = struct {
    position: Position,
    zoom: f32,
};

pub const TileRectangle = struct {
    pos: TilePosition,
    width: i32,
    height: i32,
};

pub const Rectangle = struct {
    pos: Position = .{ .x = 0, .y = 0 },
    width: f32 = 0,
    height: f32 = 0,
};

test "run automated tests" {
    try std.testing.expect(autoTestZig.runTestReplays() catch false);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    try startGame(allocator);
}

fn startGame(allocator: std.mem.Allocator) !void {
    std.debug.print("game run start\n", .{});
    var state: GameState = undefined;
    createGameState(&state, allocator) catch |err| {
        const formatted = try std.fmt.allocPrint(state.allocator, "{s}", .{@errorName(err)});
        try state.onStartError.displayStrings.append(.{ .string = formatted, .needDealloc = true });
        try state.onStartError.displayStrings.insert(0, .{ .string = "Game Start Failed" });
        try onStartErrorDisplayZig.displayLastErrorMessageInWindow(&state);
        return;
    };
    steamZig.steamInit(&state);
    try mainLoop(&state);
    destroyGameState(&state);
}

pub fn mainLoop(state: *GameState) !void {
    var lastTime = std.time.microTimestamp();
    var currentTime = lastTime;
    var tickTimeDiff: i64 = 0;
    var currentFramesSkipped: u8 = 0;
    const maxFrameSkips = 4;
    while (!state.gameQuit) {
        const passedTime: i64 = if (state.timeFreezed == null and !state.paused) TICK_INTERVAL_MS else 0;
        if (state.gamePhase != .modeSelect and (state.modeSelect.selectedMode == .newGamePlus or state.modeSelect.selectedMode == .practice or state.modeSelect.selectedMode == .custom)) {
            if (shouldEndLevel(state)) {
                if (state.gamePhase == .boss) {
                    state.lastBossDefeatedTime = state.gameTime;
                    for (state.players.items) |*player| {
                        const amount = @as(i32, @intFromFloat(@as(f32, @floatFromInt(state.level)) * 10.0 * ((1.0 + player.moneyBonusPerCent) * state.config.moneyGainMultiply)));
                        try playerZig.changePlayerMoneyBy(amount, player, true, state);
                    }
                    if (state.uxData.achievementGainedLastSoundTime + 100 < state.gameTime) {
                        try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BOSS_DEFEATED, 0, 0.6);
                        state.uxData.achievementGainedLastSoundTime = state.gameTime;
                    }

                    try achievementZig.awardAchievementOnBossDefeated(state);
                    if (state.playerTookDamageOnLevel == false and state.level < LEVEL_COUNT) {
                        state.continueData.bossesAced += 1;
                        state.uxData.displayBossAcedUntilTime = state.gameTime + 3_500;
                        if (state.continueData.bossesAced >= state.continueData.nextBossAceFreeContinue) {
                            state.continueData.freeContinues += 1;
                            state.uxData.displayReceivedFreeContinue = state.gameTime + 3_500;
                            state.continueData.nextBossAceFreeContinue += state.continueData.nextBossAceFreeContinueIncrease;
                            state.continueData.nextBossAceFreeContinueIncrease += 1;
                        }
                    }
                }
                try shopZig.startShoppingPhase(state, false);
            } else if (state.enemyData.enemies.items.len == 0 and state.gamePhase == .combat) {
                try startNextRound(state);
            }
            try tickSuddenDeath(state);
        } else {
            try modeSelectZig.tick(state);
        }
        try autoTestZig.tickReplayInputs(state);
        try autoTestZig.tickRecordRun(state);
        try windowSdlZig.handleEvents(state);
        if (!state.paused) {
            try playerZig.tickPlayers(state, passedTime);
            tickClouds(state, passedTime);
            try enemyZig.tickEnemies(passedTime, state);
            try bossZig.tickBosses(state, passedTime);
            tickMapObjects(state, passedTime);
            try multiplayerAfkCheck(state);
        }
        try tickGameOver(state);
        tickGameFinished(state);
        if (state.verifyMapData.checkReachable) try verifyMapZig.checkAndModifyMapIfNotEverythingReachable(state);
        try settingsMenuVulkanZig.tick(state);
        if (tickTimeDiff < 100_000 or currentFramesSkipped >= maxFrameSkips) {
            try paintVulkanZig.drawFrame(state);
            currentFramesSkipped = 0;
        } else {
            currentFramesSkipped += 1;
        }
        lastTime = currentTime;
        currentTime = std.time.microTimestamp();
        if (state.autoTest.mode == .replay and state.autoTest.maxSpeed) {
            tickTimeDiff = 100_000;
        } else {
            const timeDiff = currentTime - lastTime;
            tickTimeDiff += timeDiff - TICK_INTERVAL_MICRO_SECONDS;
            if (tickTimeDiff > 250_000) tickTimeDiff = 250_000;
            if (tickTimeDiff < -1_000) {
                const sleepTimeNano: i64 = tickTimeDiff * -1000;
                std.Thread.sleep(@intCast(sleepTimeNano));
            }
        }
        if (state.timeFreezed == null) {
            if (!state.paused) state.gameTime += TICK_INTERVAL_MS;
        } else {
            state.timeFreezed.? += TICK_INTERVAL_MS;
        }
    }
}

fn tickGameFinished(state: *GameState) void {
    if (state.gamePhase != .finished) return;
    const fontSize = state.uxData.creditsFontSize;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    if (state.uxData.creditsScrollStart) |creditsTime| {
        const scrollOffset: f32 = -@as(f32, @floatFromInt(state.gameTime - creditsTime)) / state.uxData.creditsScrollSpeedSlowdown;
        const scrollFinishedOffset = @as(f32, @floatFromInt(CREDITS_TEXTS.len)) * fontSize * onePixelYInVulkan + 1;
        const creditsPerCent = 1 - @abs(scrollOffset) / scrollFinishedOffset;
        state.camera.position.y = creditsPerCent * CREDITS_START_OFFSET_PLAYER_Y;
        if (@abs(scrollOffset) > scrollFinishedOffset) {
            state.uxData.creditsScrollStart = null;
            mapTileZig.setMapType(.default, state);
            state.camera.position.y = 0;
        }
    }
}

fn multiplayerAfkCheck(state: *GameState) !void {
    if (state.players.items.len <= 1 or state.gameOver) return;
    if (state.gamePhase == .modeSelect) return;
    const afkTime = 60_000;
    if (state.gamePhase != .shopping and state.gamePhase != .finished) {
        for (state.players.items) |player| {
            if (!player.isDead and player.inputData.lastInputTime + afkTime > state.gameTime) {
                return;
            }
        }
        if (state.lastAfkShootTime == null or state.lastAfkShootTime.? + 2000 < state.gameTime) {
            for (state.players.items) |player| {
                if (!player.isDead and player.inputData.lastInputTime + afkTime < state.gameTime) {
                    try enemyObjectFallDownZig.spawnFallDown(player.position, 2000, true, state);
                    state.lastAfkShootTime = state.gameTime;
                }
            }
        }
    } else {
        if (state.shop.kickStartTime != null and state.shop.kickStartTime.? + state.shop.durationToKick < state.gameTime) {
            state.shop.kickStartTime = null;
            var currentIndex: usize = 0;
            while (currentIndex < state.players.items.len and state.players.items.len > 1) {
                const currentPlayer = state.players.items[currentIndex];
                if (currentPlayer.inputData.lastInputTime + shopZig.SHOP_AFK_TIMER < state.gameTime) {
                    try playerZig.playerLeave(currentIndex, state);
                } else {
                    currentIndex += 1;
                }
            }
        }
    }
}

fn tickGameOver(state: *GameState) !void {
    if (state.pauseInputTime) |time| {
        if (time + 250 < state.gameTime) {
            var canPause = true;
            for (state.players.items) |player| {
                if (player.executeMovePiece != null) {
                    canPause = false;
                    break;
                }
            }
            if (canPause) {
                state.paused = true;
                state.pauseInputTime = null;
            }
        }
    }
    if (!state.gameOver and !state.paused) return;
    const timeStamp = std.time.milliTimestamp();
    if (state.uxData.continueButtonHoldStart != null and state.uxData.continueButtonHoldStart.? + state.uxData.holdDefaultDuration < timeStamp) {
        if (state.level > 1 and state.gameOver) {
            try executeContinue(state);
            state.uxData.continueButtonHoldStart = null;
        } else if (state.paused) {
            state.paused = false;
            state.uxData.continueButtonHoldStart = null;
        }
        return;
    }
    if (state.uxData.restartButtonHoldStart != null and state.uxData.restartButtonHoldStart.? + state.uxData.holdDefaultDuration < timeStamp) {
        try backToStart(state);
        state.uxData.restartButtonHoldStart = null;
        return;
    }
    if (state.uxData.quitButtonHoldStart != null and state.uxData.quitButtonHoldStart.? + state.uxData.holdDefaultDuration < timeStamp) {
        state.gameQuit = true;
        return;
    }
}

pub fn tickSuddenDeath(state: *GameState) !void {
    if (state.gameOver) return;
    if (state.gamePhase == .shopping or state.gamePhase == .finished) return;
    if (state.gamePhase == .boss and state.newGamePlus < 2) return;
    if (state.newGamePlus >= 2 and state.level == LEVEL_COUNT) return;
    if (state.round <= 1 and state.gamePhase == .combat) return;

    const timeUntilSuddenDeath = state.suddenDeathTimeMs - state.gameTime;
    if (timeUntilSuddenDeath <= 0) {
        if (!state.soundData.suddenDeathPlayed) {
            try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_SUDDEN_DEATH, 0, 1);
            state.soundData.suddenDeathPlayed = true;
        }
    } else {
        if (timeUntilSuddenDeath < 10_000) {
            if (!state.soundData.warningSoundPlayed) {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_TIME_WARNING, 0, 1);
                state.soundData.warningSoundPlayed = true;
            }
            if (timeUntilSuddenDeath < 3000 - state.soundData.tickSoundPlayedCounter * 1000) {
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_LAST_SECONDS, 0, 1);
                state.soundData.tickSoundPlayedCounter += 1;
            }
        }
        return;
    }
    if (preventSuddenDeathStartCondition(state)) return;

    const overTime = state.gameTime - state.suddenDeathTimeMs;
    const spawnInterval = 1050;
    if (@divFloor(overTime, spawnInterval) >= state.suddenDeath) {
        state.suddenDeath += 1;
        const width = state.mapData.tileRadiusWidth * 2 + 3;
        const height = state.mapData.tileRadiusHeight * 2 + 3;
        const fWidth: f32 = @floatFromInt(state.mapData.tileRadiusWidth + 1);
        const fHeight: f32 = @floatFromInt(state.mapData.tileRadiusHeight + 1);
        const fillWidth = @min(state.suddenDeath - 1, @divFloor(width, 2) + 1);
        const fillHeight = @min(state.suddenDeath - 1, @divFloor(height, 2) + 1);
        if (state.suddenDeath > 1) {
            try soundMixerZig.playRandomSound(&state.soundMixer, soundMixerZig.SOUND_BALL_GROUND_INDICIES[0..], 0, 1);
        }
        for (0..width) |i| {
            for (0..height) |j| {
                if (i > fillWidth and i < width - fillWidth - 1 and j > fillHeight and j < height - fillWidth - 1) continue;
                const x: f32 = (@as(f32, @floatFromInt(i)) - fWidth) * TILESIZE;
                const y: f32 = (@as(f32, @floatFromInt(j)) - fHeight) * TILESIZE;
                try enemyObjectFallDownZig.spawnFallDown(.{ .x = x, .y = y }, spawnInterval, false, state);
            }
        }
    }
    for (state.players.items) |*player| {
        const playerTile = gamePositionToTilePosition(player.position);
        if (@abs(playerTile.x) > state.mapData.tileRadiusWidth + 1 or @abs(playerTile.y) > state.mapData.tileRadiusHeight + 1) {
            try playerZig.playerHit(player, state);
        }
    }
}

pub fn preventSuddenDeathStartCondition(state: *GameState) bool {
    return state.level == 1 and state.gamePhase == .combat and state.newGamePlus == 0 and state.round >= state.config.roundToReachForNextLevel;
}

fn tickMapObjects(state: *GameState, passedTime: i64) void {
    var currentIndex: usize = 0;
    while (currentIndex < state.mapObjects.items.len) {
        const mapObject = &state.mapObjects.items[currentIndex];
        switch (mapObject.typeData) {
            .kunai => |kunaiData| {
                if (kunaiData.deleteTime <= state.gameTime) {
                    _ = state.mapObjects.swapRemove(currentIndex);
                    continue;
                } else {
                    const fPassedTime = @as(f32, @floatFromInt(passedTime)) / 100;
                    const stepDirection = movePieceZig.getStepDirection(kunaiData.direction);
                    mapObject.position.x += stepDirection.x * kunaiData.speed * fPassedTime;
                    mapObject.position.y += stepDirection.y * kunaiData.speed * fPassedTime;
                }
            },
        }
        currentIndex += 1;
    }
}

fn tickClouds(state: *GameState, passedTime: i64) void {
    if (state.mapData.mapType != .top) return;
    const fPassedTime: f32 = @floatFromInt(passedTime);
    for (state.mapData.paintData.backClouds[0..]) |*backCloud| {
        if (backCloud.position.x > 600 and state.gamePhase != .finished) {
            backCloud.position.x = -600 + state.seededRandom.random().float(f32) * 200;
            backCloud.position.y = -150 + state.seededRandom.random().float(f32) * 150;
            backCloud.sizeFactor = 5;
            backCloud.speed = 0.02;
        }
        backCloud.position.x += backCloud.speed * fPassedTime;
    }
    if (state.mapData.paintData.frontCloud.position.x > 1000 and state.gamePhase != .finished) {
        state.mapData.paintData.frontCloud.position.x = -800 + state.seededRandom.random().float(f32) * 300;
        state.mapData.paintData.frontCloud.position.y = -150 + state.seededRandom.random().float(f32) * 300;
        state.mapData.paintData.frontCloud.sizeFactor = 15;
        state.mapData.paintData.frontCloud.speed = 0.1;
    }

    state.mapData.paintData.frontCloud.position.x += state.mapData.paintData.frontCloud.speed * fPassedTime;
}

pub fn startNextRound(state: *GameState) !void {
    if (preventSuddenDeathStartCondition(state) and state.suddenDeathTimeMs < state.gameTime) return; // instead of sudden death => no more enemy spawns
    state.enemyData.enemies.clearRetainingCapacity();
    const timeShoesBonusTime = equipmentZig.getTimeShoesBonusRoundTime(state);
    const maxTime = state.gameTime + state.config.minimalTimePerRequiredRounds + timeShoesBonusTime;
    if (state.round < state.config.roundToReachForNextLevel) {
        state.suddenDeathTimeMs = maxTime;
        state.uxData.timeChangeVisualization = state.gameTime + 2_000;
        state.uxData.timeChange = .{ .refresh = true };
    } else {
        if (state.suddenDeathTimeMs < state.gameTime) state.suddenDeathTimeMs = state.gameTime;
        state.suddenDeathTimeMs += state.config.bonusTimePerRoundFinished;
        if (state.suddenDeathTimeMs > maxTime) {
            state.suddenDeathTimeMs = maxTime;
        }
        state.uxData.timeChangeVisualization = state.gameTime + 3_000;
        state.uxData.timeChange = .{ .timeAdded = state.config.bonusTimePerRoundFinished };
    }
    state.suddenDeath = 0;
    state.soundData.suddenDeathPlayed = false;
    state.soundData.tickSoundPlayedCounter = 0;
    state.soundData.warningSoundPlayed = false;
    state.roundStartedTime = state.gameTime;
    if (state.level == 1 and state.round == 1 and state.modeSelect.selectedMode == .newGamePlus) {
        try achievementZig.awardAchievement(.beatFirstEnemy, state);
    }
    state.round += 1;
    if (state.round >= state.config.roundToReachForNextLevel and state.gateOpenTime == null) state.gateOpenTime = state.gameTime;

    if (state.round > 1) {
        try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_ROUND_CLEARED, 0, 1);
        for (state.players.items) |*player| {
            const amount = @as(i32, @intFromFloat(@ceil(@as(f32, @floatFromInt(state.level)) * ((1.0 + player.moneyBonusPerCent) * state.config.moneyGainMultiply))));

            try playerZig.changePlayerMoneyBy(amount, player, true, state);
        }
    }
    try enemyZig.setupEnemies(state);
    adjustZoom(state);
}

pub fn startNextLevel(state: *GameState) !void {
    if (state.level >= LEVEL_COUNT) {
        try runStart(state, state.newGamePlus + 1);
        return;
    }
    try resetLevelData(state);
    state.level += 1;
    try enemyZig.setupSpawnEnemiesOnLevelChange(state);
    if (bossZig.isBossLevel(state.level)) {
        if (state.newGamePlus >= 2) {
            const timeShoesBonusTime = equipmentZig.getTimeShoesBonusRoundTime(state);
            const maxTime = state.gameTime + state.config.minimalTimePerRequiredRounds * 3 + timeShoesBonusTime;
            state.suddenDeathTimeMs = maxTime;
        }

        try bossZig.startBossLevel(state);
    } else {
        try startNextRound(state);
    }
    playerZig.movePlayerToLevelSpawnPosition(state);
    checkForEnemyAndPlayerOnSamePosition(state);
}

pub fn resetLevelData(state: *GameState) !void {
    mapTileZig.setMapType(.default, state);
    state.gateOpenTime = null;
    state.playerTookDamageOnLevel = false;
    state.suddenDeath = 0;
    state.soundData.suddenDeathPlayed = false;
    state.soundData.tickSoundPlayedCounter = 0;
    state.soundData.warningSoundPlayed = false;
    state.camera.position = .{ .x = 0, .y = 0 };
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    state.enemyData.afterImages.clearRetainingCapacity();
    state.lastAfkShootTime = null;
    mapTileZig.resetMapTiles(state.mapData.tiles);
    state.gamePhase = .combat;
    state.round = 0;
    state.statistics.uxData.displayBestPossibleTimeValue = null;
    bossZig.clearBosses(state);
    for (state.players.items) |*player| {
        try movePieceZig.resetPieces(player, false, state);
        player.lastMoveDirection = null;
        player.phase = .combat;
        if (state.level > 1) {
            player.uxData.visualizeChoiceKeys = false;
            player.uxData.visualizeMovementKeys = false;
        }
    }
}

fn checkForEnemyAndPlayerOnSamePosition(state: *GameState) void {
    const lengthX: f32 = @floatFromInt(state.mapData.tileRadiusWidth * 2 + 1);
    const lengthY: f32 = @floatFromInt(state.mapData.tileRadiusHeight * 2 + 1);
    for (state.enemyData.enemies.items) |*enemy| {
        const enemyTile = gamePositionToTilePosition(enemy.position);
        for (state.players.items) |*player| {
            const playerTile = gamePositionToTilePosition(player.position);
            if (playerTile.x == enemyTile.x and playerTile.y == enemyTile.y) {
                var enemyMoved = false;
                var tries: u32 = 0;
                const maxTries = 10;
                while (!enemyMoved and tries < maxTries) {
                    tries += 1;
                    const randomTileX: i16 = @as(i16, @intFromFloat(state.seededRandom.random().float(f32) * lengthX - lengthX / 2));
                    const randomTileY: i16 = @as(i16, @intFromFloat(state.seededRandom.random().float(f32) * lengthY - lengthY / 2));
                    const randomPos: Position = .{
                        .x = @floatFromInt(randomTileX * TILESIZE),
                        .y = @floatFromInt(randomTileY * TILESIZE),
                    };
                    if (isPositionEmpty(randomPos, state)) {
                        enemy.position = randomPos;
                        enemyMoved = true;
                    }
                }
            }
        }
    }
}

pub fn getDirectionFromTo(fromPosition: Position, toPosition: Position) u8 {
    const diffX = fromPosition.x - toPosition.x;
    const diffY = fromPosition.y - toPosition.y;
    if (@abs(diffX) > @abs(diffY)) {
        return if (diffX > 0) movePieceZig.DIRECTION_LEFT else movePieceZig.DIRECTION_RIGHT;
    } else {
        return if (diffY > 0) movePieceZig.DIRECTION_UP else movePieceZig.DIRECTION_DOWN;
    }
}

fn shouldEndLevel(state: *GameState) bool {
    if (state.gamePhase == .boss and state.bosses.items.len == 0) return true;
    if (state.gamePhase == .shopping or state.gamePhase == .finished) return false;
    var atLeastOnePlayerAlive = false;
    for (state.players.items) |*player| {
        if (!player.isDead) atLeastOnePlayerAlive = true;
        if (player.phase != .shopping and !player.isDead) {
            return false;
        }
    }
    return atLeastOnePlayerAlive;
}

fn allPlayerNoHp(state: *GameState) bool {
    for (state.players.items) |player| {
        if (!player.isDead) return false;
    }
    return true;
}

fn allPlayerOutOfMoveOptions(state: *GameState) bool {
    for (state.players.items) |player| {
        if (player.moveOptions.items.len > 0) return false;
        if (player.executeMovePiece != null) return false;
    }
    return true;
}

pub fn gameFinished(state: *GameState) !void {
    state.gamePhase = .finished;
    if (state.gameOver) {
        state.gameOver = false;
    }
    for (state.players.items) |*player| {
        player.isDead = false;
    }
    if (state.highestNewGameDifficultyBeaten < state.newGamePlus and state.modeSelect.selectedMode != .practice) {
        state.highestNewGameDifficultyBeaten = @intCast(state.newGamePlus);
        state.highestLevelBeaten = 0;
        try modeSelectZig.addNextNewGamePlusMode(state);
    }
    try statsZig.statsOnLevelFinished(state);
    state.enemyData.enemies.clearRetainingCapacity();
    state.enemyData.enemyObjects.clearRetainingCapacity();
    state.enemyData.afterImages.clearRetainingCapacity();
    state.uxData.creditsScrollStart = state.gameTime;
    bossZig.clearBosses(state);

    const creditsPlayerOffsetY = CREDITS_START_OFFSET_PLAYER_Y;
    try bossDragonZig.cutTilesForGroundBreakingEffect(CREDITS_START_OFFSET_PLAYER_Y, state);
    state.camera.position.y = creditsPlayerOffsetY;
    for (state.mapData.paintData.backClouds[0..]) |*cloud| {
        cloud.position.y = creditsPlayerOffsetY;
    }
    for (state.players.items) |*player| {
        player.inAirHeight -= creditsPlayerOffsetY;
        if (player.startedFallingState != null) {
            player.startedFallingState = null;
        }
    }
    if (!state.autoTest.zigTest and state.modeSelect.selectedMode == .newGamePlus) try autoTestZig.saveRecordingToFile(state);
}

pub fn backToStart(state: *GameState) anyerror!void {
    if (state.uxData.settingsMenuUx.menuOpen) {
        state.uxData.settingsMenuUx.menuOpen = false;
        state.uxData.settingsMenuUx.gamePadSelectIndex = null;
    }
    if (state.highestNewGameDifficultyBeaten > -1 or state.highestLevelBeaten >= 25) {
        try modeSelectZig.startModeSelect(state);
    } else {
        state.modeSelect.selectedMode = .{ .newGamePlus = 0 };
        try runStart(state, 0);
    }
}

pub fn runStart(state: *GameState, newGamePlus: u32) anyerror!void {
    autoTestZig.startRecordingRun(state);
    try statsZig.statsSaveOnRestart(state);
    mapTileZig.setMapType(.default, state);
    state.config = .{};
    if (state.modeSelect.selectedMode == .custom) state.config = state.modeSelect.modeCustomData.config;
    state.paused = false;
    state.pauseInputTime = null;
    state.timeFreezed = null;
    state.gameOver = false;
    state.camera.position = .{ .x = 0, .y = 0 };
    state.level = 0;
    state.round = 0;
    state.newGamePlus = newGamePlus;
    state.gamePhase = .combat;
    state.gameTime = 0;
    state.roundStartedTime = 0;
    state.lastBossDefeatedTime = 0;
    state.continueData = .{};
    state.continueData.freeContinues += state.config.additionalFreeContinues;
    state.uxData.achievementGained.clearRetainingCapacity();
    state.uxData.achievementGainedLastSoundTime = 0;
    state.uxData.continueButtonHoldStart = null;
    if (newGamePlus == 0) state.continueData.freeContinues += 2;
    if (state.enemyData.movePieceEnemyMovePiece) |movePiece| {
        state.allocator.free(movePiece.steps);
        state.enemyData.movePieceEnemyMovePiece = null;
    }
    mapTileZig.resetMapTiles(state.mapData.tiles);
    for (state.players.items) |*player| {
        try playerZig.resetPlayer(player, state);
    }
    for (0..state.shop.equipOptionsLastLevelInShop.len) |i| {
        state.shop.equipOptionsLastLevelInShop[i] = 0;
    }
    bossZig.clearBosses(state);
    state.spriteCutAnimations.clearRetainingCapacity();
    state.mapObjects.clearAndFree();
    state.verifyMapData.lastCheckTime = 0;
    state.verifyMapData.checkReachable = false;
    state.uxData.displayBossAcedUntilTime = null;
    state.uxData.displayReceivedFreeContinue = null;
    state.statistics.uxData.displayGoldRunValue = null;
    state.statistics.currentRunStats.levelDatas.clearRetainingCapacity();
    state.statistics.currentRunStats.newGamePlus = newGamePlus;
    state.statistics.currentRunStats.playerCount = @intCast(state.players.items.len);
    try startNextLevel(state);
    achievementZig.initAchievementsOnRestart(state);
    if (state.modeSelect.selectedMode == .practice) {
        achievementZig.stopTrackingAchievmentForThisRun(state);
        state.statistics.active = false;
    }
}

pub fn adjustZoom(state: *GameState) void {
    const stairsAdditionTileWidth: u32 = if (state.gamePhase == .combat) 3 else 0;
    const mapSizeWidth: f32 = @floatFromInt((state.mapData.tileRadiusWidth * 2 + 1 + stairsAdditionTileWidth) * TILESIZE);
    const mapSizeHeight: f32 = @floatFromInt((state.mapData.tileRadiusHeight * 2 + 1) * TILESIZE);
    const widthPerCent = mapSizeWidth / state.windowData.widthFloat;
    const heightPerCent = mapSizeHeight / state.windowData.heightFloat;
    state.uxData.gameVulkanArea.width = 1.5;
    state.uxData.gameVulkanArea.height = 1.5;
    var targetMapScreenPerCent: f32 = state.uxData.gameVulkanArea.width / 2;
    if (state.gamePhase == .shopping) {
        state.uxData.gameVulkanArea.height = 1.9;
        targetMapScreenPerCent = state.uxData.gameVulkanArea.height / 2;
    }

    const biggerPerCent = @max(widthPerCent, heightPerCent);
    state.camera.zoom = targetMapScreenPerCent / biggerPerCent;
    if (state.players.items.len > 1 and stairsAdditionTileWidth > 0) {
        //offset so stairs are not under player2UI
        state.camera.position.x = @as(f32, @floatFromInt(stairsAdditionTileWidth)) * TILESIZE / 2;
    }
    playerZig.determinePlayerUxPositions(state);
    state.uxData.creditsFontSize = state.windowData.heightFloat * 0.15;
}

pub fn isGameOver(state: *GameState) bool {
    for (state.players.items) |*player| {
        if (!player.isDead) return false;
    }
    return true;
}

pub fn createGameState(state: *GameState, allocator: std.mem.Allocator) !void {
    const seededRandom = std.Random.DefaultPrng.init(std.crypto.random.int(u64));
    state.* = .{
        .players = std.ArrayList(playerZig.Player).init(allocator),
        .bosses = std.ArrayList(bossZig.Boss).init(allocator),
        .shop = .{ .buyOptions = std.ArrayList(shopZig.ShopBuyOption).init(allocator) },
        .mapData = try mapTileZig.createMapData(allocator),
        .statistics = statsZig.createStatistics(allocator),
        .inputJoinData = .{
            .inputDeviceDatas = std.ArrayList(inputZig.InputJoinDeviceData).init(allocator),
            .disconnectedGamepads = std.ArrayList(u32).init(allocator),
        },
        .tempStringBuffer = try allocator.alloc(u8, 20),
        .seededRandom = seededRandom,
        .autoTest = .{ .recording = .{ .runEventData = std.ArrayList(autoTestZig.GameEventData).init(allocator) } },
        .onStartError = .{ .displayStrings = std.ArrayList(onStartErrorDisplayZig.StringAllocData).init(allocator) },
        .uxData = .{ .achievementGained = std.ArrayList(achievementZig.AchievementGainedDisplayData).init(allocator) },
    };
    state.allocator = allocator;
    try windowSdlZig.initWindowSdl(state);
    try initVulkanZig.initVulkan(state);
    try soundMixerZig.createSoundMixer(state, state.allocator);
    try enemyZig.initEnemy(state);
    state.spriteCutAnimations = std.ArrayList(CutSpriteAnimation).init(state.allocator);
    state.mapObjects = std.ArrayList(MapObject).init(state.allocator);
    try state.players.append(playerZig.createPlayer(allocator));
    statsZig.loadStatisticsDataFromFile(state);
    fileSaveZig.loadSettingsFromFile(state) catch {
        windowSdlZig.setFullscreen(true, state);
    };
    try modeSelectZig.initModeSelectData(state);
    if (fileSaveZig.loadCurrentRunFromFile(state)) {
        std.debug.print("load last run successfull\n", .{});
    } else |err| {
        std.debug.print("err: {}\n", .{err});
        try backToStart(state);
    }
}

pub fn destroyGameState(state: *GameState) void {
    fileSaveZig.saveCurrentRunToFile(state) catch std.debug.print("save current run failed\n", .{});
    fileSaveZig.saveSettingsToFile(state) catch std.debug.print("save settings failed\n", .{});
    statsZig.destroyAndSave(state) catch std.debug.print("save stats failed\n", .{});
    initVulkanZig.destroyPaintVulkan(&state.vkState, state.allocator) catch {
        std.debug.print("failed to destroy window and vulkan\n", .{});
    };
    soundMixerZig.destroySoundMixer(state);
    windowSdlZig.destroyWindowSdl(state);
    for (state.players.items) |*player| {
        playerZig.destroyPlayer(player, state);
    }
    state.players.deinit();
    for (state.bosses.items) |*boss| {
        const levelBossData = bossZig.LEVEL_BOSS_DATA.get(boss.typeData);
        if (levelBossData.deinit) |deinit| deinit(boss, state.allocator);
    }
    state.bosses.deinit();
    state.shop.buyOptions.deinit();
    state.spriteCutAnimations.deinit();
    state.mapObjects.deinit();
    state.inputJoinData.inputDeviceDatas.deinit();
    state.inputJoinData.disconnectedGamepads.deinit();
    state.allocator.free(state.tempStringBuffer);
    state.autoTest.recording.runEventData.deinit();
    for (state.onStartError.displayStrings.items) |*item| {
        if (item.needDealloc) state.allocator.free(item.string);
    }
    state.onStartError.displayStrings.deinit();
    state.uxData.achievementGained.deinit();
    mapTileZig.deinit(state);
    enemyZig.destroyEnemyData(state);
    modeSelectZig.destroyModeSelectData(state);
}

pub fn executeContinue(state: *GameState) !void {
    if (state.level < 2) return;
    if (state.autoTest.mode == .record) {
        try state.autoTest.recording.runEventData.append(.{ .eventData = .useContinue, .gameTime = state.gameTime + TICK_INTERVAL_MS });
    }

    const cost = getMoneyCostsForContinue(state);
    if (!hasEnoughMoney(cost, state)) return;
    var openMoney = cost;
    if (openMoney > 0) {
        const averagePlayerCosts = @divFloor(openMoney, state.players.items.len);
        for (state.players.items) |*player| {
            const pay = @min(averagePlayerCosts, player.money);
            try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(pay)), player, true, state);
            openMoney -|= pay;
        }
        if (openMoney > 0) {
            for (state.players.items) |*player| {
                const pay = @min(openMoney, player.money);
                try playerZig.changePlayerMoneyBy(-@as(i32, @intCast(pay)), player, true, state);
                openMoney -|= pay;
                if (openMoney == 0) break;
            }
        }
        state.continueData.paidContinues +|= 1;
    } else {
        state.continueData.freeContinues -|= 1;
    }
    for (state.players.items) |*player| {
        if (player.equipment.equipmentSlotsData.head == null) {
            _ = equipmentZig.equip(equipmentZig.getEquipmentOptionByIndexScaledToLevel(0, state.level).equipment, true, player);
        }
        if (player.equipment.equipmentSlotsData.body == null) {
            _ = equipmentZig.equip(equipmentZig.getEquipmentOptionByIndexScaledToLevel(4, state.level).equipment, true, player);
        }
        player.isDead = false;
        player.animateData.ears.lastUpdateTime = state.gameTime;
    }
    if (state.gamePhase != .shopping) {
        state.level -= 1;
        try shopZig.startShoppingPhase(state, true);
    }
    state.gameOver = false;
}

pub fn getMoneyCostsForContinue(state: *GameState) u32 {
    if (state.modeSelect.selectedMode == .practice) {
        return 0;
    }
    if (state.continueData.freeContinues > 0) {
        return 0;
    }
    const costs: u32 = (state.continueData.paidContinues + 1) * state.level * 5 * @as(u32, @intCast(state.players.items.len));
    return costs;
}

pub fn hasEnoughMoney(moneyAmount: u32, state: *GameState) bool {
    var maxPlayerMoney: u32 = 0;
    for (state.players.items) |*player| {
        maxPlayerMoney += player.money;
    }
    return maxPlayerMoney >= moneyAmount;
}

pub fn isPositionEmpty(position: Position, state: *GameState) bool {
    const tilePosition = gamePositionToTilePosition(position);
    return isTileEmpty(tilePosition, state);
}

pub fn isTileEmpty(tilePosition: TilePosition, state: *GameState) bool {
    for (state.enemyData.enemies.items) |enemy| {
        const enemyTile = gamePositionToTilePosition(enemy.position);
        if (enemyTile.x == tilePosition.x and enemyTile.y == tilePosition.y) return false;
    }
    for (state.bosses.items) |boss| {
        const bossTile = gamePositionToTilePosition(boss.position);
        if (bossTile.x == tilePosition.x and bossTile.y == tilePosition.y) return false;
    }
    for (state.players.items) |player| {
        const playerTile = gamePositionToTilePosition(player.position);
        if (playerTile.x == tilePosition.x and playerTile.y == tilePosition.y) return false;
    }
    const mapTileType = mapTileZig.getMapTilePositionType(tilePosition, &state.mapData);
    if (mapTileType == .wall) return false;

    return true;
}

pub fn calculateDistance(pos1: Position, pos2: Position) f32 {
    const diffX = pos1.x - pos2.x;
    const diffY = pos1.y - pos2.y;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY));
}

pub fn calculateDistance3D(x1: f32, y1: f32, z1: f32, x2: f32, y2: f32, z2: f32) f32 {
    const diffX = x1 - x2;
    const diffY = y1 - y2;
    const diffZ = z1 - z2;
    return @floatCast(@sqrt(diffX * diffX + diffY * diffY + diffZ * diffZ));
}

pub fn calculateDirection(start: Position, end: Position) f32 {
    return @floatCast(std.math.atan2(end.y - start.y, end.x - start.x));
}

pub fn calculateDistancePointToLine(point: Position, linestart: Position, lineEnd: Position) f32 {
    const A: Position = .{ .x = point.x - linestart.x, .y = point.y - linestart.y };
    const B: Position = .{ .x = lineEnd.x - linestart.x, .y = lineEnd.y - linestart.y };

    const dot = A.x * B.x + A.y * B.y;
    const len_sq = B.x * B.x + B.y * B.y;
    var param: f32 = -1;
    if (len_sq != 0) //in case of 0 length line
        param = dot / len_sq;

    var xx: f32 = 0;
    var yy: f32 = 0;

    if (param < 0) {
        xx = linestart.x;
        yy = linestart.y;
    } else if (param > 1) {
        xx = lineEnd.x;
        yy = lineEnd.y;
    } else {
        xx = linestart.x + param * B.x;
        yy = linestart.y + param * B.y;
    }

    const dx = point.x - xx;
    const dy = point.y - yy;
    return @sqrt(dx * dx + dy * dy);
}

pub fn moveByDirectionAndDistance(position: Position, direction: f32, distance: f32) Position {
    return .{
        .x = position.x + @cos(direction) * distance,
        .y = position.y + @sin(direction) * distance,
    };
}

pub fn rotateAroundPoint(point: Position, pivot: Position, angle: f32) Position {
    const translatedX = point.x - pivot.x;
    const translatedY = point.y - pivot.y;

    const s = @sin(angle);
    const c = @cos(angle);

    const rotatedX = c * translatedX - s * translatedY;
    const rotatedY = s * translatedX + c * translatedY;

    return Position{ .x = rotatedX + pivot.x, .y = rotatedY + pivot.y };
}

pub fn isTilePositionInTileRectangle(tilePosition: TilePosition, tileRectangle: TileRectangle) bool {
    return tileRectangle.pos.x <= tilePosition.x and tileRectangle.pos.x + tileRectangle.width > tilePosition.x and
        tileRectangle.pos.y <= tilePosition.y and tileRectangle.pos.y + tileRectangle.height > tilePosition.y;
}

pub fn isPositionInRectangle(optPosition: ?Position, rectangle: Rectangle) bool {
    if (optPosition) |position| {
        return rectangle.pos.x <= position.x and rectangle.pos.x + rectangle.width > position.x and
            rectangle.pos.y <= position.y and rectangle.pos.y + rectangle.height > position.y;
    }
    return false;
}

pub fn gamePositionToTilePosition(position: Position) TilePosition {
    return .{
        .x = @intFromFloat(@floor((position.x + TILESIZE / 2) / TILESIZE)),
        .y = @intFromFloat(@floor((position.y + TILESIZE / 2) / TILESIZE)),
    };
}

pub fn tilePositionToGamePosition(tilePosition: TilePosition) Position {
    return .{
        .x = @as(f32, @floatFromInt(tilePosition.x * TILESIZE)),
        .y = @as(f32, @floatFromInt(tilePosition.y * TILESIZE)),
    };
}

pub fn colorConv(r: f32, g: f32, b: f32) [4]f32 {
    return .{ std.math.pow(f32, r, 2.2), std.math.pow(f32, g, 2.2), std.math.pow(f32, b, 2.2), 1 };
}
