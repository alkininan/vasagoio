local _, V = ...
local function rgb(hex)
    return {tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255}
end
V.Tokens = {
    revision = 10, reference = {width = 2560, height = 1440}, radius = 10,
    colors = {
        panel = rgb("0B0B0B"), raised = rgb("151515"), deep = rgb("060606"), track = rgb("030303"),
        healthHigh = rgb("151515"), healthLow = rgb("5B5B5B"), meter = rgb("272727"),
        text = rgb("E8EDF2"), muted = rgb("B6C0CA"), iconText = rgb("F0F3F7"),
        information = rgb("A8D7EB"), informationFill = rgb("486C89"),
        danger = rgb("E4A0A8"), dangerFill = rgb("8B4E57"), range = rgb("AB2D3C"),
        attention = rgb("E7CC82"), attentionFill = rgb("866242"),
    },
    class = {HUNTER = rgb("95AE78"), WARRIOR = rgb("BC9972"), DRUID = rgb("CC9561"),
        MAGE = rgb("83B7C5"), PRIEST = rgb("E8EDF2"), PALADIN = rgb("C996AB"),
        ROGUE = rgb("D4BE70"), SHAMAN = rgb("87A5D5"), WARLOCK = rgb("B09AC6")},
    resource = {MANA = rgb("456A8C"), RAGE = rgb("9E5149"), ENERGY = rgb("75602F"), FOCUS = rgb("8F5B2B")},
    alpha = {unit = .56, hud = .40, input = .24, window = .84, range = .30},
    controls = {selection = "marker", markerHeight = 2, markerInset = 8, markerBottom = 2,
        disabledAlpha = .45, hoverAlpha = .92, pressedAlpha = .95},
    units = {
        large = {width = 320, height = 64, portrait = 64, health = 46, power = 16, gap = 2},
        medium = {width = 224, height = 48, portrait = 48, health = 34, power = 12, gap = 2},
        small = {width = 192, height = 32, portrait = 32, health = 22, power = 8, gap = 2},
        xsmall = {width = 128, height = 32, portrait = 0, health = 28, power = 4, gap = 0},
    },
    typography = {
        name = {size = 16, line = 24}, amount = {size = 16, line = 24}, compact = {size = 14, line = 16},
        heading = {size = 24, line = 32}, title = {size = 32, line = 40}, body = {size = 16, line = 24},
        chat = {size = 16, line = 24, face = "narrow"},
        hotkey = {size = 14, line = 16, face = "narrowBold"}, count = {size = 14, line = 16, face = "narrowBold"},
        countdown = {size = 18, line = 24, face = "narrowBold"}, compactCountdown = {size = 16, line = 16, face = "narrowBold"},
        aura = {size = 14, line = 16},
    },
    action = {size = 42, petSize = 32, gap = 8, columns = 16, rows = 3, petCount = 10,
        x = 884, y = 1290, width = 792, petY = 1246, petWidth = 392, rowGap = 12,
        brightness = .92, saturation = 1, opacity = 1, cooldownRemaining = .80, cooldownElapsed = .12,
        signalHeight = 3, signalGap = 2, signalInset = 6},
    aura = {size = 36, prioritySize = 28, gap = 8, wrapGap = 16, healthGap = 8},
    hud = {height = 186, bottom = 8, chatWidth = 480, mapWidth = 216, meterWidth = 248, splitGap = 16, labelHeight = 32},
    nameplate = {width = 192, health = 24, cast = 16, castGap = 8, aura = 28, auraGap = 8, amountSize = 14},
}
