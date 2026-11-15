-- ScreenBackdrop: Optionsseite (im Spiel unter Optionen -> AddOns), hier in
-- einem schlichten Behaelter statt Blizzards Einstellungsfenster.
return {
    addons = { "ScreenBackdrop" },
    uiScale = 0.77,
    crop = { frames = { "ForeverRenderSettingsBox" } },
    steps = { { run = function() Settings.OpenToCategory("ScreenBackdrop") end }, { advance = 0.5 } },
}
