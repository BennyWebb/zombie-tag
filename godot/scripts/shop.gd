class_name ShopMenu
extends MenuScreen
## The shop (src/shop.js): weapons, Heart Medicine, armour and cool outfits. Walk in through the
## door; choose with up and down, and buy with the attack button.

const ROWS_SHOWN := 4 # the list scrolls to show this many rows at a time

var cursor := 0
var partner: Hero = null # your sister, in 2-player mode, so you can give her Tag Bux
var first := 0 # the first row shown


func _init() -> void:
	super(Color("ff6fae"), PURPLE, YELLOW, Color("ff4f8b"), Color("e05a00"))


## Every row: weapons, then medicine, armour, outfits, giving Tag Bux to your sister (with two
## players), and the way out.
func ids() -> Array:
	var c: Dictionary = Data.config
	var give := ["give"] if partner else []
	return c.weapons.keys() + c.items.keys() + c.armour.keys() + c.outfits.keys() + give + ["leave"]


static func thing(id: String) -> Dictionary:
	var c: Dictionary = Data.config
	for group in [c.weapons, c.items, c.armour, c.outfits]:
		if group.has(id):
			return group[id]
	return {}


## A weapon or armour you could buy (not medicine or outfits).
func is_upgrade(id: String) -> bool:
	var w := thing(id)
	return not w.is_empty() and status(id).kind in ["buy", "dear"] and not w.has("hearts") and not w.has("covers")


func open(the_hero: Hero) -> void:
	hero = the_hero
	# start on something useful: a free stick if you need one, medicine if you're hurt, else the
	# next weapon or armour to buy (the dearest you can afford, or the cheapest you can't yet)
	var upgrades := ids().filter(is_upgrade)
	upgrades.sort_custom(func(a, b): return thing(a).price < thing(b).price)
	var affordable := upgrades.filter(func(id): return thing(id).price <= hero.tag_bux)
	var pick: String = affordable.back() if affordable else upgrades.front() if upgrades else "leave"
	if hero.hearts < Data.config.player.hearts and Data.config.items.medicine.price <= hero.tag_bux:
		pick = "medicine"
	if hero.weapon == null:
		pick = "spikyStick"
	cursor = ids().find(pick)
	say("Welcome to the shop! 🛍️")
	wait = 0.25
	visible = true
	draw()


## What a row shows on its right ({ label } or { price }) and what kind of row it is right now.
func status(id: String) -> Dictionary:
	var p := hero
	if id == "leave":
		return { label = "Back outside", kind = "leave" }
	if id == "give":
		var amount: int = Data.config.giveTagBux
		return { price = amount, kind = "buy" if p.tag_bux >= amount else "dear" }
	var w := thing(id)
	var can := func(): return { price = int(w.price), kind = "buy" if p.tag_bux >= w.price else "dear" }
	if w.has("hearts"):
		return { label = "Hearts full", kind = "full" } if p.hearts >= Data.config.player.hearts else can.call()
	if w.has("covers"):
		if id in p.wearing:
			return { label = "✔ Wearing", kind = "wearing" }
		if id in p.outfits:
			return { label = "Wear it", kind = "owned" }
		return can.call()
	if w.has("blocks"):
		var best := p.best_armour()
		if best == id:
			return { label = "✔ Wearing", kind = "holding" }
		if best != "" and Data.config.armour[best].blocks >= w.blocks:
			return { label = "You have better", kind = "locked" }
		return can.call()
	if p.weapon != null and p.weapon.id == id:
		return { label = "✔ Holding", kind = "holding" }
	if p.owns(id):
		return { label = "Hold it", kind = "owned" }
	if w.price == 0:
		return { label = "Free when you have no weapon", kind = "locked" } if p.weapon != null else { label = "FREE!", kind = "free" }
	return can.call()


## Returns true when you chose "Leave".
func handle_input(event: InputEvent) -> bool:
	if wait > 0:
		return false
	var n := ids().size()
	if event.is_action_pressed(hero.act("walk_forward")):
		cursor = (cursor + n - 1) % n
		Sound.play("tick")
	elif event.is_action_pressed(hero.act("walk_back")):
		cursor = (cursor + 1) % n
		Sound.play("tick")
	elif event.is_action_pressed(hero.act("attack")):
		if choose():
			return true
	else:
		return false
	draw()
	return false


func choose() -> bool:
	var p := hero
	var id: String = ids()[cursor]
	if id == "leave":
		return true
	var s := status(id)
	var w := thing(id)
	if id == "give":
		var amount: int = Data.config.giveTagBux
		if s.kind == "dear":
			Sound.play("nope")
			say("You need %d Tag Bux to give" % amount, "bad")
		else:
			Sound.play("kaching")
			p.tag_bux -= amount
			partner.tag_bux += amount
			say("You gave %d Tag Bux to %s! 🎁" % [amount, partner.look.name], "good")
		return false
	# a happy sound for anything that worked, a buzz for anything that didn't
	Sound.play("nope" if s.kind in ["dear", "locked", "full"] else "kaching" if s.kind in ["buy", "free"] else "select")
	match s.kind:
		"holding":
			say("You're already %s the %s!" % ["wearing" if w.has("blocks") else "holding", w.name])
		"wearing":
			p.take_off(id)
			say("You took off the %s" % w.name)
		"owned":
			if w.has("covers"):
				p.wear(id)
				say("Looking good in the %s! %s" % [w.name, w.icon], "good")
			else:
				p.hold(id)
				say("Now you're holding the %s %s" % [w.name, w.icon], "good")
		"free":
			p.give_stick()
			say("Here's a free Spiky Stick! 🪵", "good")
		"locked":
			say("You've already got better armour!" if w.has("blocks") else "You can have a free one when you have no weapon", "bad")
		"full":
			say("Your hearts are already full! ❤️❤️❤️")
		"dear":
			say("You need %d more Tag Bux. Go pop some zombies!" % (w.price - p.tag_bux), "bad")
		"buy":
			p.tag_bux -= int(w.price)
			if w.has("covers"):
				p.outfits.append(id)
				p.wear(id)
				say("Ka-ching! You're wearing the %s! %s" % [w.name, w.icon], "good")
			elif w.has("blocks"):
				p.add_armour(id)
				say("Ka-ching! %s It blocks %d %s every level!" % [w.icon, w.blocks, "hit" if w.blocks == 1 else "hits"], "good")
			elif w.has("hearts"):
				p.hearts = mini(Data.config.player.hearts, p.hearts + int(w.hearts))
				say("Yum! You got a heart back ❤️", "good")
			else:
				p.add_weapon(id)
				say("Ka-ching! You got the %s! %s" % [w.name, w.icon], "good")
	return false


## Power as little bangs, or a number for the really strong weapons.
static func power(damage: float) -> String:
	var n := maxi(1, roundi(damage))
	return "💥".repeat(n) if n <= 5 else "💥×%d" % n


func draw() -> void:
	var p := hero
	title.text = "🛍️ The Shop"
	clear(top_right)
	var hearts := HBoxContainer.new()
	for i in Data.config.player.hearts:
		var h := HudIcon.new(HudIcon.Kind.HEART, 38)
		h.full = i < p.hearts
		hearts.add_child(h)
	for i in p.shields_max:
		var s := HudIcon.new(HudIcon.Kind.SHIELD, 36)
		s.full = i < p.shields
		hearts.add_child(s)
	top_right.add_child(hearts)
	top_right.add_child(pill(bux(p.tag_bux, 40)))

	var rows := []
	for id in ids():
		var s := status(id)
		if id == "leave":
			rows.append({ icon = "🚪", name = "Leave", kind = "leave", label = s.label })
			continue
		if id == "give":
			var row := { icon = "🎁", name = "Give %d Tag Bux to %s" % [Data.config.giveTagBux, partner.look.name],
				about = "As many times as you like" }
			row.merge(s)
			rows.append(row)
			continue
		var w := thing(id)
		var about: String = w.get("about", "")
		if w.has("damage"):
			about = "Power %s · %s" % [power(w.damage), about]
		if w.has("blocks"):
			about = "Blocks %d %s every level" % [w.blocks, "hit" if w.blocks == 1 else "hits"]
		if w.has("covers"):
			about = ("Just for looks. %s will see it!" % partner.look.name if partner else "Just for looks!") \
				+ (" (choose it again to take it off)" if s.kind == "wearing" else "")
		var row := { icon = w.icon, name = w.name, about = about }
		row.merge(s)
		rows.append(row)
	# scroll so the chosen row is always on screen
	first = clampi(first, cursor - ROWS_SHOWN + 1, cursor)
	show_rows(rows, cursor, first, ROWS_SHOWN)
	help.text = "🡑 🡓 choose  ·  %s: buy" % Controls.button()
