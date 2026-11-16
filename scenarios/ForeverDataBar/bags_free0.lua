-- ForeverDataBar: Taschen mit nur 0 freien Plätzen (Symbolfarbe).
local state = require("_data").Full()
local items = {}
for i = 1, 16 - 0 do items[i] = { id = 8766, count = 20 } end
state.bags = { [0] = { size = 16, items = items } }
return {
    addons = { "ForeverDataBar" },
    uiScale = 0.77,
    crop = "auto",
    state = state,
}
