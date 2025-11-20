const std = @import("std");
const main = @import("../main.zig");
const paintVulkanZig = @import("paintVulkan.zig");
const vk = paintVulkanZig.vk;
const fontVulkanZig = @import("fontVulkan.zig");
const imageZig = @import("../image.zig");
const inputZig = @import("../input.zig");
const windowSdlZig = @import("../windowSdl.zig");
const sdl = windowSdlZig.sdl;
const playerZig = @import("../player.zig");
const config = @import("config");

pub const SettingsUx = struct {
    menuOpen: bool = false,
    settingsIcon: main.Rectangle = undefined,
    uiSizeDelayed: f32 = 1,
    uiSizeSlider: f32 = 1,
    uiTabs: [3]UiTabsData = [_]UiTabsData{
        .{ .uiElements = &UI_ELEMENTS_MAIN, .label = "main" },
        .{ .uiElements = &UI_ELEMENTS_SPEEDRUN_STATS, .label = "stats" },
        .{ .uiElements = &UI_ELEMENTS_INFO, .label = "info" },
    },
    activeTabIndex: usize = 0,
    hoverTabIndex: ?usize = null,
    gamePadSelectIndex: ?usize = null, // 0 => tab selected. > 0 -> UIElement + 1 index
    baseFontSize: f32 = 26,
    settingsIconHovered: bool = false,
};
const BUTTON_HOLD_DURATION_MS = 2000;
const SPACING_PIXELS = 5.0;
var UI_ELEMENTS_MAIN = [_]UiElementData{
    .{ .typeData = .{ .holdButton = .{ .label = "Restart", .onHoldDurationFinished = onHoldButtonRestart } }, .information = &[_][]const u8{"hold to restart"} },
    .{ .typeData = .{ .holdButton = .{ .label = "Kick Players", .onHoldDurationFinished = onHoldButtonKickPlayers } }, .information = &[_][]const u8{"hold to kick players but one"} },
    .{ .typeData = .{ .checkbox = .{ .label = "Fullscreen", .onSetChecked = onCheckboxFullscreen, .checked = true } } },
    .{
        .typeData = .{ .checkbox = .{ .label = "Time Freeze", .onSetChecked = onCheckboxFreezeOnHit, .checked = false } },
        .information = &[_][]const u8{ "freeze time when taking damage in singleplayer", "useful to determine what damaged you" },
    },
    .{ .typeData = .{ .slider = .{ .label = "Volume", .valuePerCent = 1, .onChange = onSliderChangeVolume } } },
    .{ .typeData = .{ .slider = .{ .label = "UI Size", .valuePerCent = 0.5, .onStopHolding = onSliderStopHoldingUxSize } } },
    .{
        .typeData = .{ .checkbox = .{ .label = "Mouse Hover Info", .onSetChecked = onCheckboxMouseHoverInfo, .checked = true } },
        .information = &[_][]const u8{"Display info on mouse Hover for some UI elements"},
    },
    .{ .typeData = .{ .holdButton = .{ .label = "Quit", .onHoldDurationFinished = onHoldButtonQuit } } },
};

var UI_ELEMENTS_SPEEDRUN_STATS = [_]UiElementData{
    .{ .typeData = .{ .checkbox = .{ .label = "Speedrun Stats", .onSetChecked = onCheckboxSpeedrunStats, .checked = false } } },
    .{
        .typeData = .{ .checkbox = .{ .label = "Column Time", .onSetChecked = onCheckboxStatsColumnTime, .checked = true } },
        .active = false,
        .information = &[_][]const u8{ "Displays time since run start for you current level.", "Displays time of best run for next levels", "displays time used for current run in past levels." },
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Column +/-", .onSetChecked = onCheckboxStatsColumnPlusMinus, .checked = true } },
        .active = false,
        .information = &[_][]const u8{"Displays time difference to best run."},
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Column Gold", .onSetChecked = onCheckboxStatsColumnGold, .checked = true } },
        .active = false,
        .information = &[_][]const u8{"Displays time difference to fastest level time."},
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Row Time in Shop", .onSetChecked = onCheckboxStatsTimeInShop, .checked = true } },
        .active = false,
        .information = &[_][]const u8{"Displays time spend in shop for currren run"},
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Row Best Run", .onSetChecked = onCheckboxStatsBestRun, .checked = false } },
        .active = false,
        .information = &[_][]const u8{"Displays time of your furthest or fastest completed run."},
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Row Gold Run", .onSetChecked = onCheckboxStatsGoldRun, .checked = false } },
        .active = false,
        .information = &[_][]const u8{ "Displays time for theoretical optimal run.", "Gets calculated by adding up all level gold times.", "Shop times excluded." },
    },
    .{
        .typeData = .{ .checkbox = .{ .label = "Row Best Time", .onSetChecked = onCheckboxStatsBestTime, .checked = false } },
        .active = false,
        .information = &[_][]const u8{ "Displays time for theoretical optimal remaining run.", "Gets calculated by adding up all level gold times for all remaining levels.", "Shop times excluded." },
    },
    .{ .typeData = .{ .checkbox = .{ .label = "Group Levels in 5", .onSetChecked = onCheckboxStatsGroupLevels, .checked = true } }, .active = false },
    .{ .typeData = .{ .slider = .{ .label = "Position X", .valuePerCent = 0.5, .onChange = onSliderStatsPositionX } }, .active = false },
    .{ .typeData = .{ .slider = .{ .label = "Position Y", .valuePerCent = 0.5, .onChange = onSliderStatsPositionY } }, .active = false },
    .{ .typeData = .{ .slider = .{ .label = "Next Level Count", .valuePerCent = 0, .onChange = onSliderStatsNextLevelCount } }, .active = false },
    .{ .typeData = .{ .slider = .{ .label = "Past Level Count", .valuePerCent = 0.5, .altDisplayValue = 25, .onChange = onSliderStatsPastLevelCount } }, .active = false },
};

var UI_ELEMENTS_INFO = [_]UiElementData{
    .{
        .typeData = .{ .text = .{ .label = std.fmt.comptimePrint("Version: 1.0.{s}:{s}", .{ config.gitCommitCount, config.gitHash }) } },
    },
    .{
        .typeData = .{ .text = .{ .label = "Multiplayer" } },
        .information = &[_][]const u8{
            "Player joins after holding a button for 5 seconds",
            "Keyboard Player Controll Mappings:",
            "    1: WASD 123",
            "    2: IJKL 789",
            "    3: Arrow Keys + Keypad 123",
            "Player leaves after holding a button for 5 seconds",
        },
    },
    .{
        .typeData = .{ .text = .{ .label = "Shop" } },
        .information = &[_][]const u8{
            "After finishing a level you enter a shop when stepping onto the stairs",
            "In the shop you can move without using move pieces",
            "Leave the shop by stepping onto stairs",
            "",
            "Each player has an area for move piece changes in the shop",
            "Tiles with icons are buttons",
            "Move over them to press",
            "Modes:",
            "    Add: Choose and add a new piece to your collection",
            "    Delete: Choose and delete a piece from your collection",
            "    Cut: Choose a piece from your collection and set a marker to cut",
            "    Combine: Choose two pieces from your collection to combine",
            "Cost is based on level",
        },
    },
    .{
        .typeData = .{ .text = .{ .label = "Shop Mode: Combine" } },
        .information = &[_][]const u8{
            "The Move Piece Combine Mode has 3 steps",
            "    1. Choose the first piece to combine with",
            "    2. Choose the second piece to combine with",
            "    3. Rotate Combine Direction",
            "The extra button on the left side jumps through the steps",
            "When the pay button is not transparent you can pay",
        },
    },
    .{
        .typeData = .{ .text = .{ .label = "Shop: Equipment" } },
        .information = &[_][]const u8{
            "You have 4 equipment slots: head, chest, feet and weapon",
            "    You can only equip one item per slot",
            "",
            "You buy items by moving onto the tile with the price",
            "    You can return an item by moving onto the tile again",
            "    as long as you do not leave the shop",
            "",
            "Price of equipment is based on level",
            "    For most equipments it is 10x Level",
            "",
            "Reasons for not being able to buy:",
            "    - not enough money",
            "    - items is not an upgrade",
        },
    },
};

const UiElement = enum {
    slider,
    checkbox,
    holdButton,
    text,
};

const UiElementTypeData = union(UiElement) {
    slider: UiElementSliderData,
    checkbox: UiElementCheckboxData,
    holdButton: UiElementHoldButtonData,
    text: UiElementTextData,
};

const UiTabsData = struct {
    label: []const u8,
    uiSize: f32 = 1,
    uiElements: []UiElementData,
    labelRec: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
    contentRec: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
};

const UiElementData = struct {
    typeData: UiElementTypeData,
    active: bool = true,
    hovering: bool = false,
    information: ?[]const []const u8 = null,
    informationHover: bool = false,
    informationHoverRec: main.Rectangle = .{ .pos = .{ .x = 0, .y = 0 }, .width = 0, .height = 0 },
};

const UiElementHoldButtonData = struct {
    rec: main.Rectangle = .{},
    holdStartTime: ?i64 = null,
    label: []const u8,
    baseHeight: f32 = 80,
    onHoldDurationFinished: *const fn (state: *main.GameState) anyerror!void,
};

const UiElementTextData = struct {
    rec: main.Rectangle = .{},
    label: []const u8,
    baseHeight: f32 = 80,
};

const UiElementCheckboxData = struct {
    rec: main.Rectangle = .{},
    checked: bool = false,
    hovering: bool = false,
    label: []const u8,
    baseSize: f32 = 50,
    onSetChecked: *const fn (checked: bool, state: *main.GameState) anyerror!void,
};

const UiElementSliderData = struct {
    sliderWidth: f32 = 0,
    sliderHeight: f32 = 0,
    recDragArea: main.Rectangle = undefined,
    valuePerCent: f32,
    altDisplayValue: ?i32 = null,
    hovering: bool = false,
    holding: bool = false,
    label: []const u8,
    baseHeight: f32 = 40,
    onChange: ?*const fn (sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void = null,
    onStopHolding: ?*const fn (sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void = null,
};

pub fn setupUiLocations(state: *main.GameState) void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    settingsMenuUx.uiSizeDelayed = settingsMenuUx.uiSizeSlider * state.windowData.heightFloat / 800;
    const uiSizeFactor = settingsMenuUx.uiSizeDelayed;
    const vulkanSpacingX = SPACING_PIXELS * onePixelXInVulkan * uiSizeFactor;
    const vulkanSpacingY = SPACING_PIXELS * onePixelYInVulkan * uiSizeFactor;

    const iconWidth = 40 * onePixelXInVulkan * uiSizeFactor;
    const iconHeight = 40 * onePixelYInVulkan * uiSizeFactor;
    settingsMenuUx.settingsIcon = .{
        .height = iconHeight,
        .width = iconWidth,
        .pos = .{
            .x = 1 - iconWidth - vulkanSpacingX,
            .y = -1 + vulkanSpacingY,
        },
    };

    const tabsHeight = settingsMenuUx.baseFontSize * 2 / state.windowData.heightFloat * uiSizeFactor + vulkanSpacingY * 2;
    var tabOffsetX: f32 = 0;
    for (0..settingsMenuUx.uiTabs.len) |tabCount| {
        const tabIndex = settingsMenuUx.uiTabs.len - 1 - tabCount;
        const tab = &settingsMenuUx.uiTabs[tabIndex];
        const tabTextWidth = fontVulkanZig.getTextVulkanWidth(tab.label, settingsMenuUx.baseFontSize, state) * uiSizeFactor;
        const tabWidth = tabTextWidth + vulkanSpacingX * 2;
        tab.labelRec = .{
            .pos = .{ .x = 0.99 - tabWidth + tabOffsetX, .y = -1 + vulkanSpacingY + iconHeight },
            .width = tabWidth,
            .height = tabsHeight,
        };
        tabOffsetX -= tab.labelRec.width;
    }
    for (&settingsMenuUx.uiTabs) |*tab| {
        settupUiLocationSingleTab(tab, settingsMenuUx.baseFontSize, uiSizeFactor, state);
        if (tab.contentRec.pos.y + tab.contentRec.height > 0.99) {
            const overAmount = (tab.contentRec.pos.y + tab.contentRec.height - 0.99);
            const cutPerCent = (overAmount / (tab.contentRec.height - overAmount)) + 1;
            const reducedUiSizeFactor = uiSizeFactor / cutPerCent;
            settupUiLocationSingleTab(tab, settingsMenuUx.baseFontSize, reducedUiSizeFactor, state);
        }
    }
}

fn settupUiLocationSingleTab(tab: *UiTabsData, baseFontSize: f32, uiSizeFactor: f32, state: *main.GameState) void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const vulkanSpacingX = SPACING_PIXELS * onePixelXInVulkan * uiSizeFactor;
    const vulkanSpacingY = SPACING_PIXELS * onePixelYInVulkan * uiSizeFactor;
    const vulkanSpacingLargerY = 20.0 * onePixelYInVulkan * uiSizeFactor;
    const sliderSpacingX = 20.0 * onePixelXInVulkan * uiSizeFactor;
    const infoWidth = baseFontSize * onePixelXInVulkan * uiSizeFactor + vulkanSpacingX;
    const infoHeight = baseFontSize * onePixelYInVulkan * uiSizeFactor + vulkanSpacingY;
    const sliderWidth = 20 * onePixelXInVulkan * uiSizeFactor;
    const dragAreaWidth = 255 * onePixelXInVulkan * uiSizeFactor - sliderSpacingX * 2 - sliderWidth;
    tab.uiSize = uiSizeFactor;
    var maxTabWidth: f32 = 0;
    tab.contentRec.width = 0;
    tab.contentRec.height = 0;
    tab.contentRec.pos.y = tab.labelRec.pos.y + tab.labelRec.height;

    var offsetY: f32 = tab.contentRec.pos.y;
    for (tab.uiElements) |*element| {
        switch (element.typeData) {
            .holdButton => |*data| {
                const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, baseFontSize, state) * uiSizeFactor;
                data.rec = main.Rectangle{
                    .height = data.baseHeight / state.windowData.heightFloat * uiSizeFactor,
                    .width = textWidthEstimate + vulkanSpacingX * 2,
                    .pos = .{
                        .x = tab.contentRec.pos.x + vulkanSpacingX,
                        .y = offsetY + vulkanSpacingY,
                    },
                };
                var widthEstimate = data.rec.width + vulkanSpacingX * 2;
                if (element.information != null) {
                    element.informationHoverRec = .{
                        .pos = .{
                            .x = data.rec.pos.x + data.rec.width + vulkanSpacingX,
                            .y = data.rec.pos.y,
                        },
                        .width = infoWidth,
                        .height = infoHeight,
                    };
                    widthEstimate += infoWidth + vulkanSpacingX;
                }

                if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                offsetY = data.rec.pos.y + data.rec.height;
            },
            .checkbox => |*data| {
                data.rec = main.Rectangle{
                    .height = data.baseSize / state.windowData.heightFloat * uiSizeFactor,
                    .width = data.baseSize / state.windowData.widthFloat * uiSizeFactor,
                    .pos = .{
                        .x = tab.contentRec.pos.x + vulkanSpacingX,
                        .y = offsetY + vulkanSpacingLargerY,
                    },
                };
                const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, baseFontSize, state) * uiSizeFactor;
                var widthEstimate = textWidthEstimate + data.rec.width + vulkanSpacingX * 3;
                if (element.information != null) {
                    element.informationHoverRec = .{
                        .pos = .{
                            .x = data.rec.pos.x + widthEstimate - vulkanSpacingX,
                            .y = data.rec.pos.y,
                        },
                        .width = infoWidth,
                        .height = infoHeight,
                    };
                    widthEstimate += infoWidth + vulkanSpacingX;
                }

                if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                offsetY = data.rec.pos.y + data.rec.height;
            },
            .slider => |*data| {
                const labelOffsetY = baseFontSize * onePixelYInVulkan * uiSizeFactor;
                offsetY += labelOffsetY;
                data.sliderWidth = sliderWidth;
                data.sliderHeight = data.baseHeight / state.windowData.heightFloat * uiSizeFactor;
                data.recDragArea = main.Rectangle{
                    .height = data.baseHeight / 4 / state.windowData.heightFloat * uiSizeFactor,
                    .width = dragAreaWidth,
                    .pos = .{
                        .x = tab.contentRec.pos.x + sliderWidth / 2 + vulkanSpacingX,
                        .y = offsetY + vulkanSpacingLargerY + data.baseHeight / 8 * 3 / state.windowData.heightFloat * uiSizeFactor,
                    },
                };
                const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, baseFontSize, state) * uiSizeFactor;
                const numberWidthEstimate = baseFontSize * uiSizeFactor * 3 * onePixelXInVulkan + vulkanSpacingX * 2;
                var widthEstimate = @max(dragAreaWidth + sliderWidth, textWidthEstimate + numberWidthEstimate) + vulkanSpacingX * 2;
                if (element.information != null) {
                    element.informationHoverRec = .{
                        .pos = .{
                            .x = data.recDragArea.pos.x + textWidthEstimate + numberWidthEstimate - vulkanSpacingX,
                            .y = data.recDragArea.pos.y - data.sliderHeight / 8 * 3 - baseFontSize * onePixelYInVulkan * uiSizeFactor,
                        },
                        .width = infoWidth,
                        .height = infoHeight,
                    };
                    widthEstimate = @max(dragAreaWidth + sliderWidth, textWidthEstimate + numberWidthEstimate + infoWidth + vulkanSpacingX) + vulkanSpacingX * 2;
                }
                if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                offsetY = offsetY + vulkanSpacingLargerY + data.sliderHeight;
            },
            .text => |*data| {
                const textWidthEstimate = fontVulkanZig.getTextVulkanWidth(data.label, baseFontSize, state) * uiSizeFactor;
                data.rec = main.Rectangle{
                    .height = data.baseHeight / state.windowData.heightFloat * uiSizeFactor,
                    .width = textWidthEstimate + vulkanSpacingX * 2,
                    .pos = .{
                        .x = tab.contentRec.pos.x + vulkanSpacingX,
                        .y = offsetY + vulkanSpacingY,
                    },
                };
                var widthEstimate = data.rec.width + vulkanSpacingX * 2;
                if (element.information != null) {
                    element.informationHoverRec = .{
                        .pos = .{
                            .x = data.rec.pos.x + data.rec.width + vulkanSpacingX,
                            .y = data.rec.pos.y,
                        },
                        .width = infoWidth,
                        .height = infoHeight,
                    };
                    widthEstimate += infoWidth + vulkanSpacingX;
                }

                if (widthEstimate > maxTabWidth) maxTabWidth = widthEstimate;
                offsetY = data.rec.pos.y + data.rec.height;
            },
        }

        tab.contentRec.height = offsetY - tab.contentRec.pos.y + vulkanSpacingY;
        tab.contentRec.width = maxTabWidth;
    }

    tab.contentRec.pos.x = 0.99 - tab.contentRec.width;
    for (tab.uiElements) |*element| {
        switch (element.typeData) {
            .holdButton => |*data| {
                const moveTo = tab.contentRec.pos.x + vulkanSpacingX;
                element.informationHoverRec.pos.x += moveTo - data.rec.pos.x;
                data.rec.pos.x = moveTo;
            },
            .checkbox => |*data| {
                const moveTo = tab.contentRec.pos.x + vulkanSpacingX;
                element.informationHoverRec.pos.x += moveTo - data.rec.pos.x;
                data.rec.pos.x = moveTo;
            },
            .slider => |*data| {
                const moveTo = tab.contentRec.pos.x + sliderWidth / 2 + vulkanSpacingX;
                element.informationHoverRec.pos.x += moveTo - data.recDragArea.pos.x;
                data.recDragArea.pos.x = moveTo;
            },
            .text => |*data| {
                const moveTo = tab.contentRec.pos.x + vulkanSpacingX;
                element.informationHoverRec.pos.x += moveTo - data.rec.pos.x;
                data.rec.pos.x = moveTo;
            },
        }
    }
}

pub fn mouseMove(state: *main.GameState) !void {
    if (state.vulkanMousePosition == null) return;
    const vulkanMousePos = state.vulkanMousePosition.?;
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    if (main.isPositionInRectangle(vulkanMousePos, settingsMenuUx.settingsIcon)) {
        settingsMenuUx.settingsIconHovered = true;
        return;
    }
    if (settingsMenuUx.settingsIconHovered) {
        settingsMenuUx.settingsIconHovered = false;
    }
    if (!settingsMenuUx.menuOpen) return;

    settingsMenuUx.hoverTabIndex = null;
    for (&settingsMenuUx.uiTabs, 0..) |*tab, tabIndex| {
        if (main.isPositionInRectangle(vulkanMousePos, tab.labelRec)) {
            settingsMenuUx.hoverTabIndex = tabIndex;
            break;
        }
    }

    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        if (!element.active) continue;
        switch (element.typeData) {
            .holdButton => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    element.hovering = true;
                } else {
                    element.hovering = false;
                    if (data.holdStartTime != null) {
                        data.holdStartTime = null;
                    }
                }
            },
            .checkbox => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    element.hovering = true;
                } else {
                    element.hovering = false;
                }
            },
            .slider => |*data| {
                const recSlider: main.Rectangle = .{ .pos = .{
                    .x = data.recDragArea.pos.x + data.valuePerCent * data.recDragArea.width - data.sliderWidth / 2,
                    .y = data.recDragArea.pos.y - data.sliderHeight / 8 * 3,
                }, .width = data.sliderWidth, .height = data.sliderHeight };

                if (main.isPositionInRectangle(vulkanMousePos, recSlider)) {
                    element.hovering = true;
                } else {
                    element.hovering = false;
                }
                if (data.holding) {
                    const valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                    data.valuePerCent = valuePerCent;
                    if (data.onChange) |onChange| try onChange(valuePerCent, element, state);
                    setupUiLocations(state);
                }
            },
            .text => {},
        }
        if (element.information != null) {
            if (main.isPositionInRectangle(vulkanMousePos, element.informationHoverRec)) {
                element.informationHover = true;
            } else {
                element.informationHover = false;
            }
        }
    }
}

pub fn mouseUp(state: *main.GameState) !void {
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        if (!element.active) continue;
        switch (element.typeData) {
            .holdButton => |*data| {
                data.holdStartTime = null;
            },
            .checkbox, .text => {},
            .slider => |*data| {
                if (data.holding) {
                    if (state.vulkanMousePosition) |vulkanMousePos| {
                        const valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                        if (data.onChange) |onChange| try onChange(valuePerCent, element, state);
                        if (data.onStopHolding) |stopHold| try stopHold(valuePerCent, element, state);
                    }
                }
                data.holding = false;
            },
        }
    }
}

pub fn mouseDown(state: *main.GameState) !void {
    if (state.vulkanMousePosition == null) return;
    const vulkanMousePos = state.vulkanMousePosition.?;
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    if (main.isPositionInRectangle(vulkanMousePos, settingsMenuUx.settingsIcon)) {
        settingsMenuUx.menuOpen = !settingsMenuUx.menuOpen;
        return;
    }
    if (!settingsMenuUx.menuOpen) return;
    for (&settingsMenuUx.uiTabs, 0..) |*tab, tabIndex| {
        if (main.isPositionInRectangle(vulkanMousePos, tab.labelRec)) {
            settingsMenuUx.activeTabIndex = tabIndex;
            return;
        }
    }
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        if (!element.active) continue;
        switch (element.typeData) {
            .holdButton => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.holdStartTime = std.time.milliTimestamp();
                    return;
                }
            },
            .checkbox => |*data| {
                if (main.isPositionInRectangle(vulkanMousePos, data.rec)) {
                    data.checked = !data.checked;
                    try data.onSetChecked(data.checked, state);
                    return;
                }
            },
            .slider => |*data| {
                const interactBox: main.Rectangle = .{
                    .pos = .{ .x = data.recDragArea.pos.x - data.sliderWidth / 2, .y = data.recDragArea.pos.y - data.sliderHeight / 8 * 3 },
                    .width = data.recDragArea.width + data.sliderWidth,
                    .height = data.sliderHeight,
                };
                if (main.isPositionInRectangle(vulkanMousePos, interactBox)) {
                    data.valuePerCent = @min(@max(0, @as(f32, @floatCast(vulkanMousePos.x - data.recDragArea.pos.x)) / data.recDragArea.width), 1);
                    data.holding = true;
                    if (data.onChange) |onChange| try onChange(data.valuePerCent, element, state);
                    setupUiLocations(state);
                    return;
                }
            },
            .text => {},
        }
    }
}

pub fn handleGamepadSettingsMenuInput(event: sdl.SDL_Event, player: *playerZig.Player, state: *main.GameState) !void {
    if (!state.gameOver and !state.paused) return;
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const chooseTab = 0;
    const deadzoneLimit = 15000;
    const playerInputIsInDeadZone = player.inputData.axis0DeadZone and player.inputData.axis1DeadZone;
    if (!state.uxData.settingsMenuUx.menuOpen) {
        if (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 3) {
            if (!settingsMenuUx.menuOpen) {
                resetMenu(state);
                settingsMenuUx.menuOpen = true;
            }
        }
    } else if (settingsMenuUx.gamePadSelectIndex) |gamePadSelectIndex| {
        const isCloseMenuInput = event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 3;
        if (isCloseMenuInput) {
            settingsMenuUx.gamePadSelectIndex = null;
            if (settingsMenuUx.menuOpen) settingsMenuUx.menuOpen = false;
            return;
        }
        if (settingsMenuUx.gamePadSelectIndex == chooseTab) {
            const isSwitchTabInputLeft = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and event.gaxis.value < -deadzoneLimit) or
                (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 13);
            if (isSwitchTabInputLeft) {
                settingsMenuUx.activeTabIndex = @mod(settingsMenuUx.activeTabIndex + settingsMenuUx.uiTabs.len - 1, settingsMenuUx.uiTabs.len);
                settingsMenuUx.hoverTabIndex = settingsMenuUx.activeTabIndex;
                return;
            }
            const isSwitchTabInputRight = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and event.gaxis.value > deadzoneLimit) or
                (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 14);
            if (isSwitchTabInputRight) {
                settingsMenuUx.activeTabIndex = @mod(settingsMenuUx.activeTabIndex + 1, settingsMenuUx.uiTabs.len);
                settingsMenuUx.hoverTabIndex = settingsMenuUx.activeTabIndex;
                return;
            }
        }
        const isSwitchUiElementInputDown = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 1 and event.gaxis.value > deadzoneLimit) or
            (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 12);
        const isSwitchUiElementInputUp = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 1 and event.gaxis.value < -deadzoneLimit) or
            (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 11);
        if (isSwitchUiElementInputDown or isSwitchUiElementInputUp) {
            const activeTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
            if (gamePadSelectIndex > 0) {
                activeTab.uiElements[gamePadSelectIndex - 1].hovering = false;
                activeTab.uiElements[gamePadSelectIndex - 1].informationHover = false;
            } else {
                settingsMenuUx.hoverTabIndex = null;
            }
            const indexLength = activeTab.uiElements.len + 1;
            if (isSwitchUiElementInputDown) {
                settingsMenuUx.gamePadSelectIndex = @mod(gamePadSelectIndex + 1, indexLength);
                while (settingsMenuUx.gamePadSelectIndex.? != 0 and activeTab.uiElements[settingsMenuUx.gamePadSelectIndex.? - 1].active == false) {
                    settingsMenuUx.gamePadSelectIndex = @mod(settingsMenuUx.gamePadSelectIndex.? + 1, indexLength);
                }
            } else {
                settingsMenuUx.gamePadSelectIndex = @mod(gamePadSelectIndex + indexLength - 1, indexLength);
                while (settingsMenuUx.gamePadSelectIndex.? != 0 and activeTab.uiElements[settingsMenuUx.gamePadSelectIndex.? - 1].active == false) {
                    settingsMenuUx.gamePadSelectIndex = @mod(settingsMenuUx.gamePadSelectIndex.? + indexLength - 1, indexLength);
                }
            }
            if (settingsMenuUx.gamePadSelectIndex.? > 0) {
                activeTab.uiElements[settingsMenuUx.gamePadSelectIndex.? - 1].hovering = true;
                activeTab.uiElements[settingsMenuUx.gamePadSelectIndex.? - 1].informationHover = true;
            } else {
                settingsMenuUx.hoverTabIndex = settingsMenuUx.activeTabIndex;
            }
            return;
        }
        if (settingsMenuUx.gamePadSelectIndex != chooseTab) {
            const activeTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
            const selectedUi = &activeTab.uiElements[gamePadSelectIndex - 1];
            switch (selectedUi.typeData) {
                .holdButton => |*data| {
                    const startHold = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and @abs(event.gaxis.value) > deadzoneLimit) or
                        (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and (event.gbutton.button == 13 or event.gbutton.button == 14));
                    const stopHold = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and @mod(event.gaxis.axis, 2) == 0 and @abs(event.gaxis.value) < deadzoneLimit) or
                        (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_UP and (event.gbutton.button == 13 or event.gbutton.button == 14));
                    if (startHold) data.holdStartTime = std.time.milliTimestamp();
                    if (stopHold) data.holdStartTime = null;
                },
                .checkbox => |*data| {
                    const toogleCheckboxInput = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and @abs(event.gaxis.value) > deadzoneLimit) or
                        (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and (event.gbutton.button == 13 or event.gbutton.button == 14));
                    if (toogleCheckboxInput) {
                        data.checked = !data.checked;
                        try data.onSetChecked(data.checked, state);
                    }
                    return;
                },
                .slider => |*data| {
                    const slideLeftInput = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and event.gaxis.value < -deadzoneLimit) or
                        (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 13);
                    const slideRightInput = (event.type == sdl.SDL_EVENT_GAMEPAD_AXIS_MOTION and playerInputIsInDeadZone and @mod(event.gaxis.axis, 2) == 0 and event.gaxis.value > deadzoneLimit) or
                        (event.type == sdl.SDL_EVENT_GAMEPAD_BUTTON_DOWN and event.gbutton.button == 14);
                    if (slideLeftInput or slideRightInput) {
                        if (slideRightInput) {
                            data.valuePerCent = @min(@max(0, data.valuePerCent + 0.05), 1);
                        } else {
                            data.valuePerCent = @min(@max(0, data.valuePerCent - 0.05), 1);
                        }
                        if (data.onChange) |onChange| try onChange(data.valuePerCent, selectedUi, state);
                        if (data.onStopHolding) |stopHold| try stopHold(data.valuePerCent, selectedUi, state);
                        return;
                    }
                },
                .text => {},
            }
        }
    }
}

pub fn resetMenu(state: *main.GameState) void {
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    settingsMenuUx.gamePadSelectIndex = 0;
    settingsMenuUx.hoverTabIndex = 0;
    for (currentTab.uiElements) |*element| {
        element.hovering = false;
        element.informationHover = false;
        switch (element.typeData) {
            .holdButton => |*data| {
                data.holdStartTime = null;
            },
            else => {},
        }
    }
}

pub fn tick(state: *main.GameState) !void {
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const timestamp = std.time.milliTimestamp();
    const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
    for (currentTab.uiElements) |*element| {
        switch (element.typeData) {
            .holdButton => |*data| {
                if (data.holdStartTime != null and data.holdStartTime.? + BUTTON_HOLD_DURATION_MS < timestamp) {
                    data.holdStartTime = null;
                    try data.onHoldDurationFinished(state);
                }
            },
            else => {},
        }
    }
}

pub fn setupVertices(state: *main.GameState) !void {
    const onePixelXInVulkan = state.windowData.onePixelXInVulkan;
    const onePixelYInVulkan = state.windowData.onePixelYInVulkan;
    const verticeData = &state.vkState.verticeData;
    const buttonFillColor: [4]f32 = .{ 0.7, 0.7, 0.7, 1 };
    const hoverColor: [4]f32 = .{ 0.4, 0.4, 0.4, 1 };
    const color: [4]f32 = .{ 1, 1, 1, 1 };
    const settingsMenuUx = &state.uxData.settingsMenuUx;
    const uiSizeFactor = settingsMenuUx.uiSizeDelayed;
    const icon = settingsMenuUx.settingsIcon;
    const fontSize: f32 = settingsMenuUx.baseFontSize * uiSizeFactor;

    if (settingsMenuUx.settingsIconHovered) {
        paintVulkanZig.verticesForRectangle(icon.pos.x, icon.pos.y, icon.width, icon.height, color, &verticeData.lines, &verticeData.triangles);
    }
    if (state.gameOver or state.paused) {
        const playerInputDeveice = inputZig.getPlayerInputDevice(&state.players.items[0]);
        if (playerInputDeveice != null and playerInputDeveice.? == .gamepad) {
            paintVulkanZig.verticesForComplexSpriteVulkan(.{
                .x = icon.pos.x - icon.width / 2,
                .y = icon.pos.y + icon.height / 2,
            }, imageZig.IMAGE_CIRCLE, fontSize * 1.5, fontSize * 1.5, 1, 0, false, false, state);
            _ = fontVulkanZig.paintText("Y", .{
                .x = icon.pos.x - icon.width + onePixelXInVulkan * 9 * uiSizeFactor,
                .y = icon.pos.y + onePixelXInVulkan * 11 * uiSizeFactor,
            }, fontSize, .{ 1, 1, 1, 1 }, state);
        }
    }
    paintVulkanZig.verticesForComplexSpriteVulkan(.{
        .x = icon.pos.x + icon.width / 2,
        .y = icon.pos.y + icon.height / 2,
    }, imageZig.IMAGE_SETTINGS_ICON, icon.width / onePixelXInVulkan, icon.height / onePixelYInVulkan, 1, 0, false, false, state);

    if (settingsMenuUx.menuOpen) {
        const vulkanSpacingX = SPACING_PIXELS * onePixelXInVulkan * uiSizeFactor;
        const vulkanSpacingY = SPACING_PIXELS * onePixelYInVulkan * uiSizeFactor;
        const menuRec = settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex].contentRec;
        paintVulkanZig.verticesForRectangle(menuRec.pos.x, menuRec.pos.y, menuRec.width, menuRec.height, color, null, &verticeData.triangles);
        const timestamp = std.time.milliTimestamp();
        var tabsOffsetX: f32 = 0;
        for (settingsMenuUx.uiTabs, 0..) |tab, tabIndex| {
            const tabsAlpha: f32 = if (tabIndex == settingsMenuUx.activeTabIndex) 1 else 0.5;
            const textWidth = fontVulkanZig.paintText(tab.label, .{
                .x = tab.labelRec.pos.x + vulkanSpacingX,
                .y = tab.labelRec.pos.y + vulkanSpacingY,
            }, fontSize, .{ 1, 1, 1, tabsAlpha }, state);
            if (tabIndex == settingsMenuUx.activeTabIndex) {
                const lines = &verticeData.lines;
                if (lines.verticeCount + 16 < lines.vertices.len) {
                    const borderColor: [4]f32 = .{ 0, 0, 0, 1 };
                    lines.vertices[lines.verticeCount + 0] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 1] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 2] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 3] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y + tab.labelRec.height }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 4] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 5] = .{ .pos = .{ tab.labelRec.pos.x + tab.labelRec.width, tab.labelRec.pos.y + tab.labelRec.height }, .color = borderColor };

                    lines.vertices[lines.verticeCount + 6] = lines.vertices[lines.verticeCount + 5];
                    lines.vertices[lines.verticeCount + 7] = .{ .pos = .{ tab.contentRec.pos.x + tab.contentRec.width, tab.contentRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 8] = lines.vertices[lines.verticeCount + 7];
                    lines.vertices[lines.verticeCount + 9] = .{ .pos = .{ tab.contentRec.pos.x + tab.contentRec.width, tab.contentRec.pos.y + tab.contentRec.height }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 10] = lines.vertices[lines.verticeCount + 9];
                    lines.vertices[lines.verticeCount + 11] = .{ .pos = .{ tab.contentRec.pos.x, tab.contentRec.pos.y + tab.contentRec.height }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 12] = lines.vertices[lines.verticeCount + 11];
                    lines.vertices[lines.verticeCount + 13] = .{ .pos = .{ tab.contentRec.pos.x, tab.contentRec.pos.y }, .color = borderColor };
                    lines.vertices[lines.verticeCount + 14] = lines.vertices[lines.verticeCount + 13];
                    lines.vertices[lines.verticeCount + 15] = .{ .pos = .{ tab.labelRec.pos.x, tab.labelRec.pos.y + tab.labelRec.height }, .color = borderColor };
                    lines.verticeCount += 16;
                }
            }
            const tabFillColor = if (tabIndex == settingsMenuUx.hoverTabIndex) hoverColor else buttonFillColor;
            paintVulkanZig.verticesForRectangle(tab.labelRec.pos.x, tab.labelRec.pos.y, tab.labelRec.width, tab.labelRec.height, tabFillColor, null, &verticeData.triangles);
            tabsOffsetX += textWidth + vulkanSpacingX * 2;
        }
        const currentTab = &settingsMenuUx.uiTabs[settingsMenuUx.activeTabIndex];
        const tabFontSize: f32 = settingsMenuUx.baseFontSize * currentTab.uiSize;
        const tabFontVulkanHeight = tabFontSize * onePixelYInVulkan;
        for (currentTab.uiElements) |*element| {
            const alpha: f32 = if (element.active) 1 else 0.3;
            const elementTextColor: [4]f32 = .{ 1, 1, 1, alpha };
            switch (element.typeData) {
                .holdButton => |*data| {
                    var restartFillColor = if (element.hovering and element.active) hoverColor else buttonFillColor;
                    restartFillColor[3] = alpha;
                    paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width, data.rec.height, restartFillColor, &verticeData.lines, &verticeData.triangles);
                    if (data.holdStartTime) |time| {
                        const timeDiff = @max(0, time + BUTTON_HOLD_DURATION_MS - timestamp);
                        const fillPerCent: f32 = 1 - @as(f32, @floatFromInt(timeDiff)) / BUTTON_HOLD_DURATION_MS;
                        const holdRecColor: [4]f32 = .{ 0.2, 0.2, 0.2, 1 };
                        paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width * fillPerCent, data.rec.height, holdRecColor, &verticeData.lines, &verticeData.triangles);
                    }
                    _ = fontVulkanZig.paintText(data.label, .{
                        .x = data.rec.pos.x,
                        .y = data.rec.pos.y + (data.rec.height - tabFontVulkanHeight) / 2,
                    }, tabFontSize, elementTextColor, state);
                },
                .checkbox => |*data| {
                    const checkboxFillColor = if (element.hovering and element.active) hoverColor else buttonFillColor;
                    paintVulkanZig.verticesForRectangle(data.rec.pos.x, data.rec.pos.y, data.rec.width, data.rec.height, checkboxFillColor, &verticeData.lines, &verticeData.triangles);
                    _ = fontVulkanZig.paintText(data.label, .{
                        .x = data.rec.pos.x + data.rec.width * 1.05,
                        .y = data.rec.pos.y - data.rec.height * 0.1,
                    }, tabFontSize, elementTextColor, state);
                    if (data.checked) {
                        paintVulkanZig.verticesForComplexSpriteVulkan(.{
                            .x = data.rec.pos.x + data.rec.width / 2,
                            .y = data.rec.pos.y + data.rec.height / 2,
                        }, imageZig.IMAGE_CHECKMARK, data.rec.width / onePixelXInVulkan, data.rec.height / onePixelYInVulkan, alpha, 0, false, false, state);
                    }
                },
                .slider => |*data| {
                    paintVulkanZig.verticesForRectangle(data.recDragArea.pos.x, data.recDragArea.pos.y, data.recDragArea.width, data.recDragArea.height, .{ 1, 1, 1, alpha }, &verticeData.lines, &verticeData.triangles);
                    var sliderFillColor = if (element.hovering and element.active) hoverColor else buttonFillColor;
                    sliderFillColor[3] = alpha;
                    const recSlider: main.Rectangle = .{ .pos = .{
                        .x = data.recDragArea.pos.x + data.valuePerCent * data.recDragArea.width - data.sliderWidth / 2,
                        .y = data.recDragArea.pos.y - data.sliderHeight / 8 * 3,
                    }, .width = data.sliderWidth, .height = data.sliderHeight };
                    paintVulkanZig.verticesForRectangle(recSlider.pos.x, recSlider.pos.y, recSlider.width, recSlider.height, sliderFillColor, &verticeData.lines, &verticeData.triangles);

                    const textWidthSlider = fontVulkanZig.paintText(
                        data.label,
                        .{ .x = data.recDragArea.pos.x, .y = recSlider.pos.y - tabFontVulkanHeight },
                        tabFontSize,
                        elementTextColor,
                        state,
                    );
                    const displayValue = if (data.altDisplayValue) |alt| alt else @as(i32, @intFromFloat(data.valuePerCent * 100));
                    _ = try fontVulkanZig.paintNumber(
                        displayValue,
                        .{ .x = data.recDragArea.pos.x + textWidthSlider + tabFontSize * onePixelXInVulkan, .y = recSlider.pos.y - tabFontVulkanHeight },
                        tabFontSize,
                        elementTextColor,
                        state,
                    );
                },
                .text => |*data| {
                    _ = fontVulkanZig.paintText(data.label, .{
                        .x = data.rec.pos.x,
                        .y = data.rec.pos.y + (data.rec.height - tabFontVulkanHeight) / 2,
                    }, tabFontSize, elementTextColor, state);
                },
            }
            if (element.active and element.information != null) {
                const infoRec = element.informationHoverRec;
                const infoFillColor: [4]f32 = if (element.informationHover) .{ 0.2, 0.2, 1, 1 } else .{ 0.7, 0.7, 1.0, 1 };
                paintVulkanZig.verticesForRectangle(infoRec.pos.x, infoRec.pos.y, infoRec.width, infoRec.height, infoFillColor, &verticeData.lines, &verticeData.triangles);
                _ = fontVulkanZig.paintText("I", .{
                    .x = infoRec.pos.x + infoRec.width / 2 - tabFontSize * onePixelXInVulkan / 4,
                    .y = infoRec.pos.y + vulkanSpacingY,
                }, tabFontSize, elementTextColor, state);
            }
        }
    }
}

///returns true if mouse hovering menu
pub fn verticesForHoverInformation(state: *main.GameState) !bool {
    if (!state.uxData.settingsMenuUx.menuOpen) return false;
    const currentTab = &state.uxData.settingsMenuUx.uiTabs[state.uxData.settingsMenuUx.activeTabIndex];
    const menuRec = currentTab.contentRec;
    for (currentTab.uiElements) |*element| {
        if (element.active and element.information != null) {
            if (element.informationHover) {
                fontVulkanZig.verticesForInfoBox(element.information.?, .{ .x = menuRec.pos.x, .y = element.informationHoverRec.pos.y }, false, state);
                break;
            }
        }
    }
    if (state.uxData.settingsMenuUx.menuOpen) {
        if (main.isPositionInRectangle(state.vulkanMousePosition, menuRec)) return true;
        for (state.uxData.settingsMenuUx.uiTabs) |tab| {
            if (main.isPositionInRectangle(state.vulkanMousePosition, tab.labelRec)) return true;
        }
    }
    return false;
}

fn onHoldButtonRestart(state: *main.GameState) anyerror!void {
    try main.backToStart(state);
}

fn onHoldButtonKickPlayers(state: *main.GameState) anyerror!void {
    for (1..state.players.items.len) |_| {
        try playerZig.playerLeave(1, state);
    }
}

fn onHoldButtonQuit(state: *main.GameState) anyerror!void {
    state.gameQuit = true;
}

fn onCheckboxFullscreen(checked: bool, state: *main.GameState) anyerror!void {
    _ = windowSdlZig.setFullscreen(checked, state);
}

fn onCheckboxFreezeOnHit(checked: bool, state: *main.GameState) anyerror!void {
    state.timeFreezeOnHit = checked;
}

fn onCheckboxMouseHoverInfo(checked: bool, state: *main.GameState) anyerror!void {
    state.uxData.enableInfoRectangles = checked;
}

fn onCheckboxSpeedrunStats(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.display = checked;
    for (state.uxData.settingsMenuUx.uiTabs) |tab| {
        if (std.mem.eql(u8, "stats", tab.label)) {
            for (1..tab.uiElements.len) |i| {
                tab.uiElements[i].active = checked;
            }
            break;
        }
    }
}

fn onCheckboxStatsColumnTime(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "Time", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsColumnPlusMinus(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "+/-", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsColumnGold(checked: bool, state: *main.GameState) anyerror!void {
    for (state.statistics.uxData.columnsData) |*column| {
        if (std.mem.eql(u8, "Gold", column.name)) {
            column.display = checked;
        }
    }
}

fn onCheckboxStatsNextLevel(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayNextLevelData = checked;
}

fn onCheckboxStatsBestRun(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayBestRun = checked;
}

fn onCheckboxStatsGoldRun(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayGoldRun = checked;
}

fn onCheckboxStatsBestTime(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayBestPossibleTime = checked;
}

fn onCheckboxStatsGroupLevels(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.groupingLevelsInFive = checked;
}

fn onCheckboxStatsTimeInShop(checked: bool, state: *main.GameState) anyerror!void {
    state.statistics.uxData.displayTimeInShop = checked;
}

fn onSliderChangeVolume(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.soundMixer.?.volume = sliderPerCent;
}

fn onSliderStopHoldingUxSize(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.uxData.settingsMenuUx.uiSizeSlider = 0.5 + sliderPerCent;
    setupUiLocations(state);
}

fn onSliderStatsPositionX(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.statistics.uxData.vulkanPosition.x = sliderPerCent * 2 - 1;
}

fn onSliderStatsPositionY(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.statistics.uxData.vulkanPosition.y = sliderPerCent * 2 - 1;
}

fn onSliderStatsPastLevelCount(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.statistics.uxData.displayLevelCount = @intFromFloat(sliderPerCent * 50);
    uiElement.typeData.slider.altDisplayValue = @intCast(state.statistics.uxData.displayLevelCount);
}

fn onSliderStatsNextLevelCount(sliderPerCent: f32, uiElement: *UiElementData, state: *main.GameState) anyerror!void {
    uiElement.typeData.slider.valuePerCent = sliderPerCent;
    state.statistics.uxData.displayNextLevelCount = @intFromFloat(sliderPerCent * 50);
    uiElement.typeData.slider.altDisplayValue = @intCast(state.statistics.uxData.displayNextLevelCount);
}
