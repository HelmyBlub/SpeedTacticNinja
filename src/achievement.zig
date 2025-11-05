const std = @import("std");
const main = @import("main.zig");
const steamZig = @import("steam.zig");
const imageZig = @import("image.zig");
const soundMixerZig = @import("soundMixer.zig");
const bossZig = @import("boss/boss.zig");

pub const AchievementData = struct {
    steamName: []const u8,
    trackingActive: bool = false,
    achieved: bool = false,
    displayName: ?[]const u8 = null,
    displayInAchievementsMode: bool = false,
    displayImageIndex: ?u8 = null,
    displayCharOnImage: ?[]const u8 = null,
    displayScale: f32 = 1,
};

pub const AchievementGainedDisplayData = struct {
    name: []const u8,
    imageIndex: ?u8 = null,
    displayCharOnImage: ?[]const u8 = null,
    displayNewGamePlus: u32 = 0,
    displayStartTime: i64,
};

pub const AchievementsEnum = enum {
    beatFirstEnemy,
    beatBoss1,
    beatBoss2,
    beatBoss3,
    beatBoss4,
    beatBoss5,
    beatBoss6,
    beatBoss7,
    beatBoss8,
    beatBoss9,
    beatGame,
    beatGamePlus1,
    beatBoss5OnNewGamePlus1,
    beatGamePlus2,
    beatBoss5OnNewGamePlus2,
    beatGameUnder45min,
    beatBoss5WithoutSpendingMoney,
    beatGameWithStartingMovePieces,
    beatGameWithoutTakingDamage,
};

pub const ACHIEVEMENTS = std.EnumArray(AchievementsEnum, AchievementData).init(.{
    .beatFirstEnemy = .{ .steamName = "BeatFirstEnemy", .displayInAchievementsMode = true, .displayImageIndex = imageZig.IMAGE_EVIL_TREE, .displayName = "first" },
    .beatBoss1 = .{ .steamName = "BeatBoss1" },
    .beatBoss2 = .{ .steamName = "BeatBoss2" },
    .beatBoss3 = .{ .steamName = "BeatBoss3" },
    .beatBoss4 = .{ .steamName = "BeatBoss4" },
    .beatBoss5 = .{ .steamName = "BeatBoss5" },
    .beatBoss6 = .{ .steamName = "BeatBoss6" },
    .beatBoss7 = .{ .steamName = "BeatBoss7" },
    .beatBoss8 = .{ .steamName = "BeatBoss8" },
    .beatBoss9 = .{ .steamName = "BeatBoss9" },
    .beatGame = .{ .steamName = "BeatGame" },
    .beatGamePlus1 = .{ .steamName = "BeatNewGamePlus1" },
    .beatBoss5OnNewGamePlus1 = .{ .steamName = "BeatBoss5OnNewGamePlus1" },
    .beatGamePlus2 = .{ .steamName = "BeatNewGamePlus2" },
    .beatBoss5OnNewGamePlus2 = .{ .steamName = "BeatBoss5OnNewGamePlus2" },
    .beatGameUnder45min = .{ .steamName = "BeatUnder45Min", .displayInAchievementsMode = true, .displayImageIndex = imageZig.IMAGE_CLOCK, .displayName = "speed", .displayScale = 4 },
    .beatBoss5WithoutSpendingMoney = .{ .steamName = "BeatBoss5WithoutSpendingAnyMoney", .displayInAchievementsMode = true, .displayImageIndex = imageZig.IMAGE_BOSS_SNAKE_HEAD, .displayName = "saving", .displayCharOnImage = "$" },
    .beatGameWithStartingMovePieces = .{ .steamName = "BeatGameWithStartingMovePieces", .displayInAchievementsMode = true, .displayImageIndex = imageZig.IMAGE_ICON_MOVE_PIECE, .displayName = "only 7", .displayScale = 4 },
    .beatGameWithoutTakingDamage = .{ .steamName = "BeatGameWithoutTakingDamage", .displayInAchievementsMode = true, .displayImageIndex = imageZig.IMAGE_ICON_HP, .displayName = "perfect", .displayScale = 4 },
});

pub fn initAchievementsOnRestart(state: *main.GameState) void {
    state.achievements.getPtr(.beatFirstEnemy).trackingActive = true;
    state.achievements.getPtr(.beatBoss1).trackingActive = true;
    state.achievements.getPtr(.beatBoss2).trackingActive = true;
    state.achievements.getPtr(.beatBoss3).trackingActive = true;
    state.achievements.getPtr(.beatBoss4).trackingActive = true;
    state.achievements.getPtr(.beatBoss5).trackingActive = true;
    state.achievements.getPtr(.beatBoss6).trackingActive = true;
    state.achievements.getPtr(.beatBoss7).trackingActive = true;
    state.achievements.getPtr(.beatBoss8).trackingActive = true;
    state.achievements.getPtr(.beatBoss9).trackingActive = true;
    state.achievements.getPtr(.beatGame).trackingActive = true;

    if (state.newGamePlus == 1) state.achievements.getPtr(.beatGamePlus1).trackingActive = true;
    if (state.newGamePlus == 1) state.achievements.getPtr(.beatBoss5OnNewGamePlus1).trackingActive = true;
    if (state.newGamePlus == 2) state.achievements.getPtr(.beatGamePlus2).trackingActive = true;
    if (state.newGamePlus == 2) state.achievements.getPtr(.beatBoss5OnNewGamePlus2).trackingActive = true;
    state.achievements.getPtr(.beatGameUnder45min).trackingActive = true;
    state.achievements.getPtr(.beatBoss5WithoutSpendingMoney).trackingActive = true;
    state.achievements.getPtr(.beatGameWithStartingMovePieces).trackingActive = true;
    state.achievements.getPtr(.beatGameWithoutTakingDamage).trackingActive = true;
}

pub fn stopTrackingAchievmentForThisRun(state: *main.GameState) void {
    var iter = state.achievements.iterator();
    while (iter.next()) |*achieve| {
        achieve.value.trackingActive = false;
    }
}

pub fn awardAchievement(achievementEnum: AchievementsEnum, state: *main.GameState) !void {
    const achievement = state.achievements.getPtr(achievementEnum);
    if (achievement.trackingActive) {
        if (!achievement.achieved) {
            achievement.achieved = true;
            if (achievement.displayInAchievementsMode) {
                try state.uxData.achievementGained.append(.{
                    .name = achievement.displayName.?,
                    .displayStartTime = state.gameTime,
                    .imageIndex = achievement.displayImageIndex,
                    .displayCharOnImage = achievement.displayCharOnImage,
                });
                if (state.uxData.achievementGainedLastSoundTime + 100 < state.gameTime) {
                    state.uxData.achievementGainedLastSoundTime = state.gameTime;
                    try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BOSS_DEFEATED, 0, 0.8);
                }
            }
        }
        steamZig.setAchievement(achievementEnum, state);
    }
}

pub fn awardAchievementOnBossDefeated(state: *main.GameState) !void {
    if (state.steam) |*steam| steam.preventStoreStats = true;
    switch (state.level) {
        5 => try awardAchievement(.beatBoss1, state),
        10 => try awardAchievement(.beatBoss2, state),
        15 => try awardAchievement(.beatBoss3, state),
        20 => try awardAchievement(.beatBoss4, state),
        25 => {
            try awardAchievement(.beatBoss5, state);
            if (state.newGamePlus == 1) try awardAchievement(.beatBoss5OnNewGamePlus1, state);
            if (state.newGamePlus == 2) try awardAchievement(.beatBoss5OnNewGamePlus2, state);
            try awardAchievement(.beatBoss5WithoutSpendingMoney, state);
        },
        30 => try awardAchievement(.beatBoss6, state),
        35 => try awardAchievement(.beatBoss7, state),
        40 => try awardAchievement(.beatBoss8, state),
        45 => try awardAchievement(.beatBoss9, state),
        50 => {
            try awardAchievement(.beatGame, state);
            if (state.newGamePlus == 1) try awardAchievement(.beatGamePlus1, state);
            if (state.newGamePlus == 2) try awardAchievement(.beatGamePlus2, state);
            if (std.time.milliTimestamp() - state.statistics.runStartedTime < 45_000 * 60) try awardAchievement(.beatGameUnder45min, state);
            try awardAchievement(.beatGameWithoutTakingDamage, state);
            try awardAchievement(.beatGameWithStartingMovePieces, state);
        },
        else => {},
    }
    if (!state.autoTest.zigTest and state.modeSelect.selectedMode == .newGamePlus) {
        if (state.highestNewGameDifficultyBeaten < state.newGamePlus and state.highestLevelBeaten < state.level and @mod(state.level, 5) == 0) {
            const bossIndex: u32 = @divFloor(state.level, 5) - 1;
            const bossArray = bossZig.LEVEL_BOSS_DATA.values;
            try state.uxData.achievementGained.append(.{
                .name = "Boss Beaten",
                .displayStartTime = state.gameTime,
                .imageIndex = bossArray[bossIndex].imageIndex,
                .displayNewGamePlus = state.newGamePlus,
            });
            if (state.uxData.achievementGainedLastSoundTime + 100 < state.gameTime) {
                state.uxData.achievementGainedLastSoundTime = state.gameTime;
                try soundMixerZig.playSound(&state.soundMixer, soundMixerZig.SOUND_BOSS_DEFEATED, 0, 0.8);
            }
        }
    }
    if (state.steam) |*steam| steam.preventStoreStats = false;
    steamZig.storeAchievements(state);
}
