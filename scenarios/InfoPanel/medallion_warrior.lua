-- InfoPanel-Medaillon als Krieger: drei Kampfwerte rechts statt vier.
local state = require("_data").Full()
state.units.player.class = "WARRIOR"
return {
    extends = "InfoPanel/full",
    state = state,
    steps = { { call = "InfoPanel:Settings.Set", args = { "panelStyle", "MEDALLION" } }, { advance = 0.5 } },
}
