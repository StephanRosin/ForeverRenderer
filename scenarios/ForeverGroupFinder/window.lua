-- ForeverGroupFinder: das Hauptfenster offen (full/classic zeigen nichts,
-- das Fenster startet geschlossen). Themes: FOREVER_THEME/FOREVER_COLOR.
return {
    extends = "ForeverGroupFinder/full",
    steps = { { call = "ForeverGroupFinder:Window.Show" }, { advance = 0.5 } },
}
