const std = @import("std");
const imageZig = @import("image.zig");
const main = @import("main.zig");
const paintVulkanZig = @import("vulkan/paintVulkan.zig");
const fontVulkanZig = @import("vulkan/fontVulkan.zig");
const playerZig = @import("player.zig");

pub const EquipmentSlotTypes = enum {
    head,
    body,
    feet,
    weapon,
};

pub const EquipmentSlotsData = struct {
    head: ?EquipmentSlotData = null,
    body: ?EquipmentSlotData = null,
    feet: ?EquipmentSlotData = null,
    weapon: ?EquipmentSlotData = null,
};

pub const EquipmentData = struct {
    equipmentSlotsData: EquipmentSlotsData = .{},
    hasWeaponHammer: bool = false,
    hasWeaponKunai: bool = false,
    hasBlindfold: bool = false,
    hasEyePatch: bool = false,
    hasRollerblades: bool = false,
    hasPirateLegLeft: bool = false,
    hasPirateLegRight: bool = false,
    hasTimeShoes: bool = false,
};

const EquipmentSlotTypeData = union(EquipmentSlotTypes) {
    head: EquipmentHeadData,
    body,
    feet,
    weapon,
};

pub const EquipmentSlotData = struct {
    effectType: EquipmentEffectTypeData,
    imageIndex: u8,
    slotTypeData: EquipmentSlotTypeData,
    returnMoney: u32 = 0,
};

const EquipmentHeadData = struct {
    bandana: bool,
    imageIndexLayer1: ?u8 = null,
    earImageIndex: u8 = imageZig.IMAGE_DOG_EAR,
    offset: main.Position = .{ .x = 0, .y = 0 },
    leftEye: bool = true,
    rightEye: bool = true,
};

const EquipmentEffectType = enum {
    none,
    hp,
    damage,
    damagePerCent,
};

const EquipmentEffectTypeData = union(EquipmentEffectType) {
    none,
    hp: EquipEffectHpData,
    damage: EquipEffectDamageData,
    damagePerCent: EquipEffectDamagePerCentData,
};

const EquipEffectDamageData = struct {
    damage: u32,
    effect: SecondaryEffect = .none,
};

const EquipEffectDamagePerCentData = struct {
    factor: f32,
    effect: SecondaryEffect = .none,
};

const EquipEffectHpData = struct {
    hp: u8,
    effect: SecondaryEffect = .none,
};

pub const SecondaryEffect = enum {
    none,
    hammer,
    kunai,
    gold,
    blind,
    oneMovePieceChoice,
    noBackMovement,
    noLeftMovement,
    noRightMovement,
    bonusTime,
};

pub const EquipmentShopOptions = struct {
    basePrice: u32,
    shopDisplayImage: u8,
    imageScale: f32 = 1.5,
    equipment: EquipmentSlotData,
};

pub const GOLD_WEAPON_BONUS = 1;
pub const KUNAI_RANGE = 3;
pub const EQUIPMENT_SHOP_OPTIONS = [_]EquipmentShopOptions{
    .{
        .basePrice = 5,
        .shopDisplayImage = imageZig.IMAGE_NINJA_HEAD,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 1 } },
            .imageIndex = imageZig.IMAGE_NINJA_HEAD,
            .slotTypeData = .{ .head = .{ .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } },
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_MILITARY_HELMET,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 2 } },
            .imageIndex = imageZig.IMAGE_MILITARY_HELMET,
            .slotTypeData = .{
                .head = .{
                    .bandana = false,
                    .earImageIndex = imageZig.IMAGE_DOG_EAR,
                    .imageIndexLayer1 = imageZig.IMAGE_DOG_HEAD,
                    .offset = imageZig.IMAGE_MILITARY_HELMET__OFFSET_GAME,
                },
            },
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_BLINDFOLD,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 1, .effect = .blind } },
            .imageIndex = imageZig.IMAGE_BLINDFOLD,
            .slotTypeData = .{
                .head = .{
                    .bandana = false,
                    .leftEye = false,
                    .rightEye = false,
                    .earImageIndex = imageZig.IMAGE_DOG_EAR,
                    .imageIndexLayer1 = imageZig.IMAGE_DOG_HEAD,
                },
            },
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_EYEPATCH,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 0.5, .effect = .oneMovePieceChoice } },
            .imageIndex = imageZig.IMAGE_EYEPATCH,
            .slotTypeData = .{
                .head = .{
                    .bandana = false,
                    .rightEye = false,
                    .earImageIndex = imageZig.IMAGE_DOG_EAR,
                    .imageIndexLayer1 = imageZig.IMAGE_DOG_HEAD,
                },
            },
        },
    },
    .{
        .basePrice = 5,
        .shopDisplayImage = imageZig.IMAGE_NINJA_CHEST_ARMOR_1,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 1 } },
            .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1,
            .slotTypeData = .body,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_NINJA_CHEST_ARMOR_2,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 2 } },
            .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_2,
            .slotTypeData = .body,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_BODY_SIXPACK,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 0.3 } },
            .imageIndex = imageZig.IMAGE_BODY_SIXPACK,
            .slotTypeData = .body,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_MILITARY_BOOTS,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 2 } },
            .imageIndex = imageZig.IMAGE_MILITARY_BOOTS,
            .slotTypeData = .feet,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_ROLLERBLADES,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 1, .effect = .noBackMovement } },
            .imageIndex = imageZig.IMAGE_ROLLERBLADES,
            .slotTypeData = .feet,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_PIRATE_LEG_LEFT,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 1, .effect = .noLeftMovement } },
            .imageIndex = imageZig.IMAGE_PIRATE_LEG_LEFT,
            .slotTypeData = .feet,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_PIRATE_LEG_RIGHT,
        .equipment = .{
            .effectType = .{ .damagePerCent = .{ .factor = 1, .effect = .noRightMovement } },
            .imageIndex = imageZig.IMAGE_PIRATE_LEG_RIGHT,
            .slotTypeData = .feet,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_TIME_SHOES,
        .equipment = .{
            .effectType = .{ .hp = .{ .hp = 1, .effect = .bonusTime } },
            .imageIndex = imageZig.IMAGE_TIME_SHOES,
            .slotTypeData = .feet,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_BLADE,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 10 } },
            .imageIndex = imageZig.IMAGE_BLADE,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 15,
        .shopDisplayImage = imageZig.IMAGE_HAMMER,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 3, .effect = .hammer } },
            .imageIndex = imageZig.IMAGE_HAMMER,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_KUNAI,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 7, .effect = .kunai } },
            .imageIndex = imageZig.IMAGE_KUNAI,
            .slotTypeData = .weapon,
        },
    },
    .{
        .basePrice = 10,
        .shopDisplayImage = imageZig.IMAGE_GOLD_BLADE,
        .equipment = .{
            .effectType = .{ .damage = .{ .damage = 5, .effect = .gold } },
            .imageIndex = imageZig.IMAGE_GOLD_BLADE,
            .slotTypeData = .weapon,
        },
    },
};

pub fn setupVerticesForShopEquipmentSecondaryEffect(topLeft: main.Position, secEffect: SecondaryEffect, fontSize: f32, state: *main.GameState) !void {
    if (secEffect == .none) return;
    var textWidth: f32 = 0;
    const textColor: [4]f32 = .{ 1, 1, 1, 1 };
    if (secEffect != .gold) textWidth = fontVulkanZig.paintTextGameMap("+", topLeft, fontSize, textColor, state);
    const iconPos: main.Position = .{
        .x = topLeft.x + textWidth + 5,
        .y = topLeft.y + fontSize / 2,
    };
    switch (secEffect) {
        .kunai => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_KUNAI_TILE_INDICATOR, 0.5, 0.5, 1, 0, false, false, state);
        },
        .hammer => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_HAMMER_TILE_INDICATOR, 0.5, 0.5, 1, 0, false, false, state);
        },
        .gold => {
            const infoWidth = fontVulkanZig.paintTextGameMap("$x", .{ .x = topLeft.x, .y = topLeft.y }, fontSize, textColor, state);
            _ = try fontVulkanZig.paintNumberGameMap(1 + GOLD_WEAPON_BONUS, .{ .x = topLeft.x + infoWidth, .y = topLeft.y }, fontSize, textColor, state);
        },
        .noBackMovement => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_ARROW_RIGHT, 0.5, 0.5, 1, std.math.pi / 2.0, false, false, state);
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_WARNING_TILE, 0.5, 0.5, 1, 0, false, false, state);
        },
        .noLeftMovement => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_ARROW_RIGHT, 0.5, 0.5, 1, std.math.pi, false, false, state);
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_WARNING_TILE, 0.5, 0.5, 1, 0, false, false, state);
        },
        .noRightMovement => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_ARROW_RIGHT, 0.5, 0.5, 1, 0, false, false, state);
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_WARNING_TILE, 0.5, 0.5, 1, 0, false, false, state);
        },
        .bonusTime => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_CLOCK, 2, 2, 1, 0, false, false, state);
        },
        .blind => {
            paintVulkanZig.verticesForComplexSprite(iconPos, imageZig.IMAGE_BLIND_ICON, 3, 3, 1, 0, false, false, state);
        },
        .oneMovePieceChoice => {
            paintVulkanZig.verticesForComplexSprite(.{ .x = iconPos.x + 6, .y = iconPos.y }, imageZig.IMAGE_NO_CHOICE, 2, 2, 1, 0, false, false, state);
        },
        .none => {},
    }
}

pub fn getEquipmentOptionByIndexScaledToLevel(index: usize, level: u32) EquipmentShopOptions {
    var option = EQUIPMENT_SHOP_OPTIONS[index];
    if (option.equipment.effectType == .damage) {
        const damageScaledToLevel = @max(1, @divFloor(@divFloor(level + 10, 5) * option.equipment.effectType.damage.damage, 10));
        option.equipment.effectType.damage.damage = damageScaledToLevel;
    }
    return option;
}

pub fn getTimeShoesBonusRoundTime(state: *main.GameState) i32 {
    const timePerShoes: i32 = @intCast(@divFloor(120_000, state.players.items.len));
    var bonusTime: i32 = 0;
    for (state.players.items) |player| {
        if (player.equipment.hasTimeShoes) bonusTime += timePerShoes;
    }
    return bonusTime;
}

pub fn equipStarterEquipment(player: *playerZig.Player) void {
    _ = equip(.{
        .effectType = .{ .hp = .{ .hp = 1 } },
        .imageIndex = imageZig.IMAGE_NINJA_HEAD,
        .slotTypeData = .{ .head = .{ .bandana = true, .earImageIndex = imageZig.IMAGE_NINJA_EAR } },
    }, false, player);
    _ = equip(.{ .effectType = .{ .hp = .{ .hp = 1 } }, .imageIndex = imageZig.IMAGE_NINJA_CHEST_ARMOR_1, .slotTypeData = .body }, false, player);
    _ = equip(.{ .effectType = .none, .imageIndex = imageZig.IMAGE_NINJA_FEET, .slotTypeData = .feet }, false, player);
    _ = equip(.{ .effectType = .{ .damage = .{ .damage = 1 } }, .imageIndex = imageZig.IMAGE_BLADE, .slotTypeData = .weapon }, false, player);
}

/// return true if item equipted
pub fn equip(equipment: EquipmentSlotData, preventDowngrade: bool, player: *playerZig.Player) bool {
    switch (equipment.slotTypeData) {
        .body => {
            return equipBody(equipment, preventDowngrade, player);
        },
        .feet => {
            return equipFeet(equipment, preventDowngrade, player);
        },
        .head => {
            return equipHead(equipment, preventDowngrade, player);
        },
        .weapon => {
            return equipWeapon(equipment, preventDowngrade, player);
        },
    }
}

pub fn getEquipSlot(slotType: EquipmentSlotTypes, player: *playerZig.Player) ?EquipmentSlotData {
    switch (slotType) {
        .body => {
            return player.equipment.equipmentSlotsData.body;
        },
        .feet => {
            return player.equipment.equipmentSlotsData.feet;
        },
        .head => {
            return player.equipment.equipmentSlotsData.head;
        },
        .weapon => {
            return player.equipment.equipmentSlotsData.weapon;
        },
    }
}

pub fn unequip(slotType: EquipmentSlotTypes, player: *playerZig.Player) void {
    switch (slotType) {
        .body => {
            _ = equipBody(null, false, player);
        },
        .feet => {
            _ = equipFeet(null, false, player);
        },
        .head => {
            _ = equipHead(null, false, player);
        },
        .weapon => {
            _ = equipWeapon(null, false, player);
        },
    }
}

pub fn damageTakenByEquipment(player: *playerZig.Player, state: *main.GameState) !bool {
    var equipBrokenImageIndex: ?u8 = null;
    var equipTookDamage = false;
    inline for (@typeInfo(EquipmentSlotsData).@"struct".fields) |field| {
        const valPtr: *?EquipmentSlotData = &@field(player.equipment.equipmentSlotsData, field.name);
        if (valPtr.* != null) {
            const effectType: EquipmentEffectTypeData = valPtr.*.?.effectType;
            if (effectType == .hp) {
                valPtr.*.?.effectType.hp.hp -= 1;
                equipTookDamage = true;
                if (valPtr.*.?.effectType.hp.hp == 0) {
                    equipBrokenImageIndex = valPtr.*.?.imageIndex;
                    unequip(valPtr.*.?.slotTypeData, player);
                }
                break;
            }
        }
    }
    if (equipBrokenImageIndex) |imageIndex| {
        try state.spriteCutAnimations.append(
            .{
                .deathTime = state.gameTime,
                .position = player.position,
                .cutAngle = 0,
                .force = 1.2,
                .colorOrImageIndex = .{ .imageIndex = imageIndex },
            },
        );
    }
    return equipTookDamage;
}

fn equipHead(optHead: ?EquipmentSlotData, preventDowngrade: bool, player: *playerZig.Player) bool {
    const optOld = player.equipment.equipmentSlotsData.head;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optHead) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);

    player.equipment.equipmentSlotsData.head = optHead;
    if (optHead) |head| {
        player.paintData.headLayer1ImageIndex = head.slotTypeData.head.imageIndexLayer1;
        player.paintData.headLayer2ImageIndex = head.imageIndex;
        player.paintData.earImageIndex = head.slotTypeData.head.earImageIndex;
        player.paintData.headLayer2Offset = head.slotTypeData.head.offset;
        player.paintData.hasBandana = head.slotTypeData.head.bandana;
        player.paintData.drawLeftEye = head.slotTypeData.head.leftEye;
        player.paintData.drawRightEye = head.slotTypeData.head.rightEye;
    } else {
        player.paintData.headLayer1ImageIndex = null;
        player.paintData.headLayer2ImageIndex = imageZig.IMAGE_DOG_HEAD;
        player.paintData.earImageIndex = imageZig.IMAGE_DOG_EAR;
        player.paintData.headLayer2Offset = .{ .x = 0, .y = 0 };
        player.paintData.hasBandana = false;
        player.paintData.drawLeftEye = true;
        player.paintData.drawRightEye = true;
    }
    return true;
}

fn equipBody(optBody: ?EquipmentSlotData, preventDowngrade: bool, player: *playerZig.Player) bool {
    const optOld = player.equipment.equipmentSlotsData.body;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optBody) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.equipmentSlotsData.body = optBody;
    if (optBody) |body| {
        player.paintData.chestArmorImageIndex = body.imageIndex;
    } else {
        player.paintData.chestArmorImageIndex = imageZig.IMAGE_NINJA_BODY_NO_ARMOR;
    }
    return true;
}

fn isDowngrade(optOldEffectType: ?EquipmentEffectTypeData, optNewEffectType: ?EquipmentEffectTypeData) bool {
    if (optOldEffectType != null and optNewEffectType != null) {
        if (@as(EquipmentEffectType, optOldEffectType.?) == @as(EquipmentEffectType, optNewEffectType.?)) {
            switch (optOldEffectType.?) {
                .damage => |damage| {
                    if (damage.damage >= optNewEffectType.?.damage.damage and @as(SecondaryEffect, damage.effect) == @as(SecondaryEffect, optNewEffectType.?.damage.effect)) {
                        return true;
                    }
                },
                .damagePerCent => |data| {
                    if (data.factor >= optNewEffectType.?.damagePerCent.factor and @as(SecondaryEffect, data.effect) == @as(SecondaryEffect, optNewEffectType.?.damagePerCent.effect)) {
                        return true;
                    }
                },
                .hp => |hp| {
                    if (hp.hp >= optNewEffectType.?.hp.hp and @as(SecondaryEffect, hp.effect) == @as(SecondaryEffect, optNewEffectType.?.hp.effect)) {
                        return true;
                    }
                },
                else => {},
            }
        }
    }
    return false;
}

fn equipFeet(optFeet: ?EquipmentSlotData, preventDowngrade: bool, player: *playerZig.Player) bool {
    const optOld = player.equipment.equipmentSlotsData.feet;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optFeet) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.equipmentSlotsData.feet = optFeet;
    if (optFeet) |feet| {
        player.paintData.feetImageIndex = feet.imageIndex;
    } else {
        player.paintData.feetImageIndex = imageZig.IMAGE_NINJA_FEET;
    }
    return true;
}

fn equipWeapon(optWeapon: ?EquipmentSlotData, preventDowngrade: bool, player: *playerZig.Player) bool {
    const optOld = player.equipment.equipmentSlotsData.weapon;
    const optOldEffectType = if (optOld) |old| old.effectType else null;
    const optNewEffectType = if (optWeapon) |new| new.effectType else null;
    if (preventDowngrade and isDowngrade(optOldEffectType, optNewEffectType)) return false;
    equipmentEffect(optNewEffectType, optOldEffectType, player);
    player.equipment.equipmentSlotsData.weapon = optWeapon;
    if (optWeapon) |weapon| {
        player.paintData.weaponImageIndex = weapon.imageIndex;
    } else {
        player.paintData.weaponImageIndex = imageZig.IMAGE_BLADE;
    }
    return true;
}

fn equipmentEffect(optNewEffectType: ?EquipmentEffectTypeData, optOldEffectType: ?EquipmentEffectTypeData, player: *playerZig.Player) void {
    if (optOldEffectType) |oldEffectType| {
        var optSecondaryEffect: ?SecondaryEffect = null;
        switch (oldEffectType) {
            .none => {},
            .damage => |damage| {
                player.damage -= damage.damage;
                optSecondaryEffect = damage.effect;
            },
            .damagePerCent => |data| {
                player.damagePerCentFactor -= data.factor;
                optSecondaryEffect = data.effect;
            },
            .hp => |data| {
                optSecondaryEffect = data.effect;
                if (optNewEffectType != null) {
                    if (player.uxData.visualizeHpChange != null) {
                        player.uxData.visualizeHpChange.? -= data.hp;
                    } else {
                        player.uxData.visualizeHpChange = -@as(i32, @intCast(data.hp));
                    }
                    player.uxData.visualizeHpChangeUntil = null;
                }
            },
        }
        if (optSecondaryEffect) |secEffect| {
            switch (secEffect) {
                .hammer => player.equipment.hasWeaponHammer = false,
                .kunai => player.equipment.hasWeaponKunai = false,
                .gold => player.moneyBonusPerCent = 0,
                .blind => player.equipment.hasBlindfold = false,
                .oneMovePieceChoice => player.equipment.hasEyePatch = false,
                .noBackMovement => player.equipment.hasRollerblades = false,
                .noLeftMovement => player.equipment.hasPirateLegRight = false,
                .noRightMovement => player.equipment.hasPirateLegLeft = false,
                .bonusTime => player.equipment.hasTimeShoes = false,
                .none => {},
            }
        }
    }
    if (optNewEffectType) |newEffectType| {
        var optSecondaryEffect: ?SecondaryEffect = null;
        switch (newEffectType) {
            .none => {},
            .damage => |damage| {
                player.damage += damage.damage;
                optSecondaryEffect = damage.effect;
            },
            .damagePerCent => |data| {
                player.damagePerCentFactor += data.factor;
                optSecondaryEffect = data.effect;
            },
            .hp => |data| {
                optSecondaryEffect = data.effect;
                if (player.uxData.visualizeHpChange != null) {
                    player.uxData.visualizeHpChange.? += data.hp;
                } else {
                    player.uxData.visualizeHpChange = data.hp;
                }
                player.uxData.visualizeHpChangeUntil = null;
            },
        }
        if (optSecondaryEffect) |secEffect| {
            switch (secEffect) {
                .hammer => player.equipment.hasWeaponHammer = true,
                .kunai => player.equipment.hasWeaponKunai = true,
                .gold => player.moneyBonusPerCent = GOLD_WEAPON_BONUS,
                .blind => player.equipment.hasBlindfold = true,
                .oneMovePieceChoice => player.equipment.hasEyePatch = true,
                .noBackMovement => player.equipment.hasRollerblades = true,
                .noLeftMovement => player.equipment.hasPirateLegRight = true,
                .noRightMovement => player.equipment.hasPirateLegLeft = true,
                .bonusTime => player.equipment.hasTimeShoes = true,
                .none => {},
            }
        }
    }
}
