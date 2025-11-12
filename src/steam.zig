const std = @import("std");
const main = @import("main.zig");
const achievementZig = @import("achievement.zig");
const builtin = @import("builtin");

const ISteamUserStats = opaque {};
var SteamAPI_InitFlat: ?*const fn (err: ?*[1024]u8) callconv(.C) u32 = null;
var SteamAPI_Shutdown: ?*const fn () callconv(.C) void = null;
var SteamAPI_SteamUserStats_v013: ?*const fn () callconv(.C) ?*ISteamUserStats = null;
var SteamAPI_ISteamUserStats_StoreStats: ?*const fn (ptr: ?*ISteamUserStats) callconv(.C) bool = null;
var SteamAPI_ISteamUserStats_ClearAchievement: ?*const fn (ptr: ?*ISteamUserStats, pchName: [*c]const u8) callconv(.C) bool = null;
var SteamAPI_ISteamUserStats_ResetAllStats: ?*const fn (ptr: ?*ISteamUserStats, bAchievementsToo: bool) callconv(.C) bool = null;
var SteamAPI_ISteamUserStats_SetAchievement: ?*const fn (ptr: ?*ISteamUserStats, pchName: [*c]const u8) callconv(.C) bool = null;
var SteamAPI_ISteamUserStats_GetAchievement: ?*const fn (ptr: ?*ISteamUserStats, pchName: [*c]const u8, pbAchieved: *bool) callconv(.C) bool = null;

const ENABLED: bool = false;
pub const SteamData = struct {
    earliestNextStoreStats: i64,
    achievementToStore: bool = false,
    preventStoreStats: bool = false,
};
const MIN_STORE_INTERVAL = 60;
var steamApiLib: ?std.DynLib = null;

pub fn setAchievement(achievementEnum: achievementZig.AchievementsEnum, state: *main.GameState) void {
    if (state.steam) |*steam| {
        const achievement = state.achievements.getPtr(achievementEnum);
        if (achievement.achieved) {
            var achieved: bool = false;
            const success = SteamAPI_ISteamUserStats_GetAchievement.?(SteamAPI_SteamUserStats_v013.?(), @ptrCast(achievement.steamName), &achieved);
            if (!achieved and success) {
                _ = SteamAPI_ISteamUserStats_SetAchievement.?(SteamAPI_SteamUserStats_v013.?(), @ptrCast(achievement.steamName));
                steam.achievementToStore = true;
                if (!steam.preventStoreStats) {
                    storeAchievements(state);
                }
            }
        }
    }
}

pub fn storeAchievements(state: *main.GameState) void {
    if (state.steam) |*steam| {
        if (!steam.achievementToStore or steam.preventStoreStats) return;
        const timestamp = std.time.timestamp();
        if (steam.earliestNextStoreStats < timestamp) {
            _ = SteamAPI_ISteamUserStats_StoreStats.?(SteamAPI_SteamUserStats_v013.?());
            steam.earliestNextStoreStats = timestamp + MIN_STORE_INTERVAL;
            steam.achievementToStore = false;
        }
    }
}

pub fn steamInit(state: *main.GameState) void {
    if (!ENABLED) {
        std.debug.print("!!!!   steam disabled    !!!!!\n", .{});
        return;
    }
    loadSteamDll() catch {
        std.debug.print("steam api lib not found\n", .{});
        return;
    };
    if (SteamAPI_InitFlat.?(null) == 0) {
        state.steam = .{ .earliestNextStoreStats = std.time.timestamp() };
        std.debug.print("steam connected\n", .{});
    } else {
        std.debug.print("steam init failed\n", .{});
    }
}

fn loadSteamDll() !void {
    const steamLibName = comptime switch (builtin.os.tag) {
        .windows => "steam_api64.dll",
        else => "libsteam_api.so",
    };
    steamApiLib = std.DynLib.open(steamLibName) catch {
        return error.steamApiLibNotFound;
    };

    SteamAPI_InitFlat = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_InitFlat),
        "SteamAPI_InitFlat",
    ) orelse return error.LookupFailed;

    SteamAPI_Shutdown = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_Shutdown),
        "SteamAPI_Shutdown",
    ) orelse return error.LookupFailed;

    SteamAPI_SteamUserStats_v013 = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_SteamUserStats_v013),
        "SteamAPI_SteamUserStats_v013",
    ) orelse return error.LookupFailed;

    SteamAPI_ISteamUserStats_StoreStats = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_ISteamUserStats_StoreStats),
        "SteamAPI_ISteamUserStats_StoreStats",
    ) orelse return error.LookupFailed;

    SteamAPI_ISteamUserStats_ClearAchievement = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_ISteamUserStats_ClearAchievement),
        "SteamAPI_ISteamUserStats_ClearAchievement",
    ) orelse return error.LookupFailed;

    SteamAPI_ISteamUserStats_SetAchievement = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_ISteamUserStats_SetAchievement),
        "SteamAPI_ISteamUserStats_SetAchievement",
    ) orelse return error.LookupFailed;

    SteamAPI_ISteamUserStats_GetAchievement = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_ISteamUserStats_GetAchievement),
        "SteamAPI_ISteamUserStats_GetAchievement",
    ) orelse return error.LookupFailed;

    SteamAPI_ISteamUserStats_ResetAllStats = steamApiLib.?.lookup(
        @TypeOf(SteamAPI_ISteamUserStats_ResetAllStats),
        "SteamAPI_ISteamUserStats_ResetAllStats",
    ) orelse return error.LookupFailed;
}

pub fn unloadGameDll() void {
    if (steamApiLib) |*lib| {
        lib.close();
    }
}
