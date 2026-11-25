-- ForeverConsumables: Optionsfenster, Reiter Leiste (Layout, Position).
return {
    extends = "ForeverConsumables/options",
    steps = { { slash = "/fcon" }, { advance = 0.2 }, { call = "ForeverConsumables:Window.ShowPage", args = { 2 } }, { advance = 0.3 } },
}
