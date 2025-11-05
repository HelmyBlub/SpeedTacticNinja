const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.standardOptimizeOption(.{});
    // const optimize: std.builtin.OptimizeMode = .ReleaseFast;

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const executableData = addExecutable(b, target, optimize, sdl_lib, zigimg_dependency, false);

    const run_cmd = b.addRunArtifact(executableData.exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.linkLibrary(sdl_lib);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    compileShared(unit_tests, zigimg_dependency, b);
    steamSetupStep(
        b,
        target,
        optimize,
    );
}

fn compileShared(compile: *std.Build.Step.Compile, zigimg: *std.Build.Dependency, b: *std.Build) void {
    const vulkan_sdk = "C:/Zeugs/VulkanSDK/1.4.313.2/";
    compile.addIncludePath(.{ .cwd_relative = vulkan_sdk ++ "Include/Volk" });
    compile.addIncludePath(.{ .cwd_relative = vulkan_sdk ++ "Include" });
    compile.addIncludePath(.{ .cwd_relative = vulkan_sdk ++ "Include/vulkan" });
    compile.addLibraryPath(.{ .cwd_relative = vulkan_sdk ++ "lib" });

    compile.addIncludePath(b.path("dependencies"));
    compile.addCSourceFile(.{ .file = b.path("dependencies/minimp3_ex.c") });
    compile.addCSourceFile(.{ .file = b.path("dependencies/volk.c") });

    compile.root_module.addImport("zigimg", zigimg.module("zigimg"));
}

fn addExecutable(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, sdl_lib: *std.Build.Step.Compile, zigimg: *std.Build.Dependency, skipInstall: bool) struct {
    exe: *std.Build.Step.Compile,
    artifact: *std.Build.Step.InstallArtifact,
} {
    const exe = b.addExecutable(.{
        .name = "speedTacticNinja",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const install_step = b.addInstallArtifact(exe, .{});
    if (target.result.os.tag == .windows) {
        if (optimize != .Debug) {
            exe.subsystem = .Windows;
        }
        install_step.dest_dir = .{ .custom = "steam/windows" };
        // this just adds the dll file to zig-out/bin dir
        install_step.step.dependOn(&b.addInstallFileWithDir(b.path("dependencies/steam_api64.dll"), .{ .custom = "steam/windows" }, "steam_api64.dll").step);
    } else {
        install_step.dest_dir = .{ .custom = "steam/linux" };
        install_step.step.dependOn(&b.addInstallFileWithDir(b.path("dependencies/libsteam_api.so"), .{ .custom = "steam/linux" }, "libsteam_api.so").step);
    }
    if (!skipInstall) b.getInstallStep().dependOn(&install_step.step);
    exe.root_module.linkLibrary(sdl_lib);
    compileShared(exe, zigimg, b);
    return .{ .exe = exe, .artifact = install_step };
}

fn steamSetupStep(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const target2 = if (target.result.os.tag == .windows)
        b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu })
    else
        b.resolveTargetQuery(.{ .cpu_arch = .x86_64, .os_tag = .windows });

    const sdl_dep = b.dependency("sdl", .{
        .target = target2,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    const zigimg_dependency = b.dependency("zigimg", .{
        .target = target2,
        .optimize = optimize,
    });
    const executableData2 = addExecutable(b, target2, optimize, sdl_lib, zigimg_dependency, true);
    const steam_step = b.step("steam", "copy files");
    steam_step.dependOn(b.getInstallStep());
    steam_step.dependOn(&executableData2.artifact.step);
    const install_data_sounds = b.addInstallDirectory(.{
        .source_dir = b.path("sounds"),
        .install_dir = .prefix,
        .install_subdir = "steam/all/sounds",
    });
    steam_step.dependOn(&install_data_sounds.step);
    const install_data_shaders = b.addInstallDirectory(.{
        .source_dir = b.path("shaders"),
        .install_dir = .prefix,
        .install_subdir = "steam/all/shaders",
    });
    steam_step.dependOn(&install_data_shaders.step);
    const install_data_images = b.addInstallDirectory(.{
        .include_extensions = &[1][]const u8{"png"},
        .source_dir = b.path("images"),
        .install_dir = .prefix,
        .install_subdir = "steam/all/images",
    });
    steam_step.dependOn(&install_data_images.step);
}
