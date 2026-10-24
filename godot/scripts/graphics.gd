class_name Graphics
## The graphics settings, so the game can be tuned to run smoothly on the TV box while you watch
## (the pause menu's "Graphics", see screens.gd). Each is a list of choices, best looking first;
## the ones further down draw less, so each frame takes less time.
##   resolution  how many dots the world is drawn with, across and down (the HUD and menus stay sharp)
##   shadows     the sun's shadows: in four layers near to far (each layer draws everything that
##               casts a shadow again), two, one, or none
##   smoothing   smoothing the jagged edges of things ("multisample anti-aliasing")
##   distance    how far you can see: anything past it isn't drawn, and the fog comes in to hide it
##   extras      the snow, sparkles and fireflies, and the glowing lamps and torches at night
##   test        for finding what takes the time on the TV box: leaves a part of the game out
##               (never saved: the game always starts with everything)
## main.gd uses them (apply_graphics), and level.gd does the shadows, distance and extras.

const OPTIONS := {
	resolution = { label = "🖼️ Sharpness", choices = ["100%", "90%", "80%", "70%", "60%", "50%"] },
	shadows = { label = "🌳 Shadows", choices = ["Best", "Good", "Simple", "Off"] },
	smoothing = { label = "✨ Smooth edges", choices = ["4x", "2x", "Off"] },
	distance = { label = "🔭 View distance", choices = ["Far", "Medium", "Near"] },
	extras = { label = "❄️ Snow and lamps", choices = ["On", "Off"] },
	test = { label = "🧪 Test: leave out", choices = ["Nothing", "HUD", "Zombies", "Scenery", "Shop and gym", "Their signs", "World", "All 3D"] },
}


## The usual settings: as good as the Shield managed at 60 fps with one player, and simpler
## shadows with two. Smooth edges start off: on a 1080p TV you can hardly see them from the sofa.
static func defaults(players: int) -> Dictionary:
	return { resolution = 0, shadows = 0 if players == 1 else 1, smoothing = 2, distance = 0, extras = 0, test = 0 }


static func resolution_scale(g: Dictionary) -> float:
	return [1.0, 0.9, 0.8, 0.7, 0.6, 0.5][g.resolution]


static func msaa(g: Dictionary) -> Viewport.MSAA:
	return [Viewport.MSAA_4X, Viewport.MSAA_2X, Viewport.MSAA_DISABLED][g.smoothing]
