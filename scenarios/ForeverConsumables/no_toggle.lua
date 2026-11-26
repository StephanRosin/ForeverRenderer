-- ForeverConsumables: Leiste ohne Zuklapp-Knopf.
return {
    extends = "ForeverConsumables/full",
    steps = { { call = "ForeverConsumables:Settings.Set", args = { "showToggle", false } },
              { call = "ForeverConsumables:Bar.Refresh" }, { advance = 0.3 } },
}
