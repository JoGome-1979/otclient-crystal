-- to-do
-- change to ItemsDatabase.setTier(UIitem) to UIitem:setTier()
ItemsDatabase = {}

-- Raridade visual por ID, independente de preco ou venda em NPC.
-- Cores: grey, green, blue, purple, yellow.
ItemsDatabase.rarityOverrides = {
    [54270] = "yellow", -- Anel da Eternidade: guardado
    [54271] = "yellow", -- Anel da Eternidade: equipado
    [54268] = "blue", -- Semente de Abobora
}

ItemsDatabase.rarityColors = {
    ["yellow"] = TextColors.yellow,
    ["purple"] = TextColors.purple,
    ["blue"] = TextColors.blue,
    ["green"] = TextColors.green,
    ["grey"] = TextColors.grey
}

local function getColorForValue(value)
    if value >= 1000000 then
        return "yellow"
    elseif value >= 100000 then
        return "purple"
    elseif value >= 10000 then
        return "blue"
    elseif value >= 1000 then
        return "green"
    elseif value >= 50 then
        return "grey"
    else
        return "white"
    end
end

function ItemsDatabase.getRarity(item)
    if type(item) == "number" then
        item = g_things.getThingType(item, ThingCategoryItem)
    end
    if not item then
        return nil
    end

    local rarity = ItemsDatabase.rarityOverrides[item:getId()]
    if rarity and ItemsDatabase.rarityColors[rarity] then
        return rarity
    end
    return getColorForValue(item:getMeanPrice() or 0)
end

local rarityClips = {
    grey = "0 0 32 32",
    green = "32 0 32 32",
    blue = "64 0 32 32",
    purple = "96 0 32 32",
    yellow = "128 0 32 32"
}

function ItemsDatabase.getClipAndImagePath(item)
    if not item then
        return nil, nil, nil
    end

    local frameOption = modules.client_options.getOption('framesRarity')
    if frameOption == "none" then
        return nil, nil, nil
    end

    local clip = rarityClips[ItemsDatabase.getRarity(item)]
    if not clip then
        return nil, nil, nil
    end

    local imagePath = "/images/ui/rarity_frames"
    if frameOption == "corners" then
        imagePath = "/images/ui/containerslot-coloredges"
    end

    local x, y, w, h = clip:match("(%d+) (%d+) (%d+) (%d+)")
    local clipObject = {
        x = tonumber(x), y = tonumber(y),
        width = tonumber(w), height = tonumber(h)
    }
    return clip, imagePath, clipObject
end

function ItemsDatabase.setRarityItem(widget, item, style)
    if not g_game.getFeature(GameColorizedLootValue) or not widget then
        return
    end

    local clip, imagePath = ItemsDatabase.getClipAndImagePath(item)

    if not imagePath then
        -- no frame applies (empty slot or frames disabled): clear a frame left by a previous item,
        -- but only if this widget is currently showing one, to avoid clobbering custom backgrounds
        local currentSource = widget:getImageSource()
        if currentSource == "/images/ui/rarity_frames" or currentSource == "/images/ui/containerslot-coloredges" then
            widget:setImageClip(nil)
            widget:setImageSource('/images/ui/item')
        end
        return
    end

    widget:setImageClip(clip)
    widget:setImageSource(imagePath)
    if style then
        widget:setStyle(style)
    end
end

function ItemsDatabase.getColorForRarity(rarity)
    return ItemsDatabase.rarityColors[rarity] or TextColors.white
end

function ItemsDatabase.setColorLootMessage(text)
    local function coloringLootName(match)
        local id, itemName = match:match("(%d+)|(.+)")
        if not id or not itemName then
            -- If pattern doesn't match itemId|itemName format, return the original match with braces
            return "{" .. match .. "}"
        end

        local itemId = tonumber(id)
        if not itemId then
            return itemName or match
        end

        local thingType = g_things.getThingType(itemId, ThingCategoryItem)
        if not thingType then
            return itemName
        end

        local rarity = ItemsDatabase.getRarity(thingType)
        if not rarity then
            return itemName
        end
        local color = ItemsDatabase.getColorForRarity(rarity)
        return "{" .. itemName .. ", " .. color .. "}"
    end
    return text:gsub("{(.-)}", coloringLootName)
end

function ItemsDatabase.getTierClip(tier)
    local xOffset = (math.min(math.max(tier, 1), 10) - 1) * 9
    return {
        x = xOffset,
        y = 0,
        width = 10,
        height = 9
    }
end

function ItemsDatabase.setTier(widget, item, isSmall)
    if not g_game.getFeature(GameThingUpgradeClassification) or not widget or not widget.tier then
        return
    end
    if isSmall == nil then
        isSmall = true
    end
    local tier = type(item) == "number" and item or (item and item:getTier()) or 0
    if tier <= 0 then
        widget.tier:setVisible(false)
        return
    end
    local config
    if isSmall then
        local normalizedTier = math.min(math.max(tier, 1), 10)
        config = {
            xOffset = (normalizedTier - 1) * 9,
            width = 10,
            height = 9,
            size = "10 9",
            source = '/images/inventory/tiers-strip'
        }
    else
        local normalizedTier = math.min(math.max(tier, 1), 18)
        local xOffset = (normalizedTier - 1) * 18 + 1
        config = {
            xOffset = xOffset,
            width = 18,
            height = 16,
            size = "18 16",
            source = '/images/inventory/tiers-strip-big'
        }
    end

    widget.tier:setImageClip({
        x = config.xOffset,
        y = 0,
        width = config.width,
        height = config.height
    })
    widget.tier:setSize(config.size)
    widget.tier:setImageSource(config.source)
    widget.tier:setImageSize(config.size)
    widget.tier:setVisible(true)
end


