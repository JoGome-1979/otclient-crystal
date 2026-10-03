-- Run from the repository root with LuaJIT.
Cyclopedia = {}
dofile(arg[1] or 'modules/game_cyclopedia/tab/items/items.lua')

local function setUpvalue(fn, name, value)
    for i = 1, 100 do
        local key = debug.getupvalue(fn, i)
        if key == name then debug.setupvalue(fn, i, value); return end
        if not key then break end
    end
    error('Missing upvalue: ' .. name)
end

local function panel()
    return { hide = function(self) self.visible = false end,
             show = function(self) self.visible = true end }
end
local clicks, destroys = 0, 0
local originalCreateItem = Cyclopedia.internalCreateItem
local ui = { InfoBase = panel(), LootValue = panel(), EmptyLabel = panel() }
function ui:isDestroyed() return self.destroyed end
ui.SelectedItem = {
    Sprite = { setItemId = function() end },
    Rarity = { setImageSource = function() end }
}
ui.SearchEdit = { setText = function(_, text, silent)
    assert(text == '' and silent, 'Clearing search must not re-enter ItemSearch')
end }
local rows = {}
ui.ItemListBase = { List = {
    destroyChildren = function()
        assert(ui.selectItem == nil, 'Selection must be released before destruction')
        assert(Cyclopedia.Items.currentItemId == nil)
        for _, row in ipairs(rows) do row.destroyed = true end
        rows = {}
        destroys = destroys + 1
    end,
    getFirstChild = function() return rows[1] end
} }
setUpvalue(Cyclopedia.ItemSearch, 'UI', ui)
Cyclopedia.AllItemList = { { getMarketData = function() return { name = 'blue backpack' } end } }
Cyclopedia.internalCreateItem = function()
    local row = { getId = function() return '100' end }
    function row:onClick()
        assert(not self.destroyed)
        clicks = clicks + 1
        ui.selectItem = self
        Cyclopedia.Items.currentItemId = 100
        setUpvalue(Cyclopedia.Items.onChangeCustomPrice, 'lastSelectedItem', self)
        setUpvalue(originalCreateItem, 'lastSelectedItemId', 100)
    end
    rows[#rows + 1] = row
end

Cyclopedia.ItemSearch('backpack')
Cyclopedia.ItemSearch('blue backpack')
assert(clicks == 2, 'A recreated result with the same ID must be selected again')
Cyclopedia.ItemSearch('no such item')
assert(#rows == 0 and ui.selectItem == nil and not ui.InfoBase.visible)
-- A price callback after clearing results must not access the destroyed row.
Cyclopedia.Items.onChangeCustomPrice({})
Cyclopedia.ItemSearch('', true)
ui.destroyed = true
local previousDestroys = destroys
Cyclopedia.ItemSearch('backpack')
assert(destroys == previousDestroys, 'Closed UI must ignore late search callbacks')
print('PASS: repeated result, empty result, stale callback, clear search, closed UI')
