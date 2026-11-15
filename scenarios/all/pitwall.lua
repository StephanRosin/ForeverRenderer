-- Alle Addons unter Pitwall mit vollem Spielstand (Pitwall-Keil in jedem Kopf).
local D = require("_data")
return { extends = "all/classic", theme = "PITWALL", state = D.Group(D.Full()), drawBlizzard = { "MinimapCluster" } }
