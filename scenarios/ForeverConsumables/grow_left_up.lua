-- ForeverConsumables: Leiste waechst nach links und oben (1 pro Reihe).
return {
    extends = "ForeverConsumables/full",
    steps = { { call = "ForeverConsumables:Settings.Set", args = { "perRow", 1 } },
              { call = "ForeverConsumables:Settings.Set", args = { "growX", "LEFT" } },
              { call = "ForeverConsumables:Settings.Set", args = { "growY", "UP" } },
              { call = "ForeverConsumables:Bar.Refresh" }, { advance = 0.3 } },
}
