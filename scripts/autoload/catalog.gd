extends Node
## Static game data: appearance options, clothing, items, properties, districts.

# ---------------------------------------------------------------- appearance
const SKIN_TONES := [
	Color("f3d3bd"), Color("e5b896"), Color("c99872"), Color("a8774f"),
	Color("86593a"), Color("6a4329"), Color("4b2e1d"), Color("e9c3a0"),
]
const HAIR_STYLES := ["slick_back", "side_part", "crew_cut", "pompadour", "long_swept", "curly_top", "buzz", "bald"]
const HAIR_STYLE_NAMES := {
	"slick_back": "Slicked Back", "side_part": "Side Part", "crew_cut": "Crew Cut",
	"pompadour": "Pompadour", "long_swept": "Long Swept", "curly_top": "Curly Top",
	"buzz": "Buzz Cut", "bald": "Clean Shaven Head",
}
const HAIR_COLOURS := [
	Color("15110f"), Color("3b2618"), Color("6b4428"), Color("a5713f"),
	Color("d8b26e"), Color("8c8c8c"), Color("e2e2dd"), Color("6e1b2c"),
]
const HAIR_COLOUR_NAMES := ["Jet Black", "Espresso", "Chestnut", "Copper", "Dirty Blond", "Steel Grey", "Silver", "Burgundy"]
const FACIAL_HAIR := ["none", "stubble", "pencil", "moustache", "goatee", "full_beard"]
const FACIAL_HAIR_NAMES := {
	"none": "Clean Shaven", "stubble": "Stubble", "pencil": "Pencil Moustache",
	"moustache": "Moustache", "goatee": "Goatee", "full_beard": "Full Beard",
}
const EYE_COLOURS := [Color("3c2a1c"), Color("5a7fa8"), Color("4f7a4a"), Color("8a6a3a"), Color("707a86")]
const EYE_COLOUR_NAMES := ["Dark Brown", "Steel Blue", "Green", "Hazel", "Grey"]
const SCARS := ["none", "cheek", "brow", "lip"]
const SCAR_NAMES := {"none": "None", "cheek": "Cheek Scar", "brow": "Brow Scar", "lip": "Lip Scar"}
const BODY_TYPES := ["lean", "standard", "broad"]
const BODY_TYPE_NAMES := {"lean": "Lean", "standard": "Athletic", "broad": "Broad"}

# ---------------------------------------------------------------- clothing
# slot -> display name, in wardrobe tab order
const SLOTS := ["jacket", "shirt", "trousers", "waistcoat", "coat", "tie", "pocket_square",
	"shoes", "gloves", "hat", "glasses", "watch", "ring", "necklace"]
const SLOT_NAMES := {
	"jacket": "Suits & Jackets", "shirt": "Shirts", "trousers": "Trousers", "waistcoat": "Waistcoats",
	"coat": "Coats", "tie": "Ties", "pocket_square": "Pocket Squares", "shoes": "Shoes",
	"gloves": "Gloves", "hat": "Hats", "glasses": "Eyewear", "watch": "Watches",
	"ring": "Rings", "necklace": "Necklaces",
}
# Slots that may be left empty.
const OPTIONAL_SLOTS := ["jacket", "waistcoat", "coat", "tie", "pocket_square", "gloves", "hat", "glasses", "watch", "ring", "necklace"]

# style keys are read by the character renderer (scripts/art/adrian.gd)
const CLOTHES := {
	# jackets / suits ------------------------------------------------------
	"suit_black": {"name": "Black Two-Piece Suit", "slot": "jacket", "style": "suit", "color": Color("15141c"), "price": 0, "grants": ["trousers_black"], "desc": "The suit Adrian arrived in. Sharp, quiet, forgettable."},
	"suit_charcoal": {"name": "Charcoal Chalk-Stripe Suit", "slot": "jacket", "style": "suit", "color": Color("3a3a44"), "accent": Color("6a6a78"), "price": 900, "grants": ["trousers_charcoal"], "desc": "Old-money chalk stripe. Comes with matching trousers."},
	"suit_midnight": {"name": "Midnight Blue Suit", "slot": "jacket", "style": "suit", "color": Color("1b2550"), "price": 1100, "grants": ["trousers_midnight"], "desc": "Looks black until the neon hits it."},
	"suit_burgundy": {"name": "Burgundy Velvet Suit", "slot": "jacket", "style": "suit", "color": Color("5e1626"), "price": 1300, "grants": ["trousers_burgundy"], "desc": "For men who want to be remembered at the jazz club."},
	"suit_cream": {"name": "Ivory Dinner Jacket", "slot": "jacket", "style": "dinner", "color": Color("e8dfc8"), "price": 1600, "grants": ["trousers_black"], "desc": "Black tie, Monte Carlo rules."},
	"jacket_leather": {"name": "Black Leather Jacket", "slot": "jacket", "style": "leather", "color": Color("1a1616"), "price": 750, "desc": "Casual. Rain runs right off it."},
	"jacket_bomber": {"name": "Olive Bomber Jacket", "slot": "jacket", "style": "bomber", "color": Color("3f4630"), "price": 400, "desc": "Ex-military surplus. Blends in at the docks."},
	# shirts --------------------------------------------------------------
	"shirt_white": {"name": "White Dress Shirt", "slot": "shirt", "style": "dress", "color": Color("e9e6df"), "price": 0, "desc": "Crisp cotton."},
	"shirt_black": {"name": "Black Dress Shirt", "slot": "shirt", "style": "dress", "color": Color("17161d"), "price": 180, "desc": "Black on black. Menacing."},
	"shirt_midnight": {"name": "Midnight Blue Shirt", "slot": "shirt", "style": "dress", "color": Color("223061"), "price": 200, "desc": "Silk blend."},
	"shirt_burgundy": {"name": "Burgundy Shirt", "slot": "shirt", "style": "dress", "color": Color("6e1b2c"), "price": 220, "desc": "The colour of a good Barolo."},
	"shirt_turtleneck": {"name": "Black Turtleneck", "slot": "shirt", "style": "turtleneck", "color": Color("141318"), "price": 260, "desc": "No tie required. Very continental."},
	"shirt_tee": {"name": "Charcoal T-Shirt", "slot": "shirt", "style": "tee", "color": Color("3b3a40"), "price": 60, "desc": "Off-duty."},
	# trousers ------------------------------------------------------------
	"trousers_black": {"name": "Black Suit Trousers", "slot": "trousers", "style": "suit", "color": Color("15141c"), "price": 0, "desc": "Pressed."},
	"trousers_charcoal": {"name": "Charcoal Trousers", "slot": "trousers", "style": "suit", "color": Color("3a3a44"), "price": 300, "desc": "Matches the chalk-stripe suit."},
	"trousers_midnight": {"name": "Midnight Trousers", "slot": "trousers", "style": "suit", "color": Color("1b2550"), "price": 320, "desc": "Matches the midnight suit."},
	"trousers_burgundy": {"name": "Burgundy Trousers", "slot": "trousers", "style": "suit", "color": Color("5e1626"), "price": 350, "desc": "Bold."},
	"trousers_cream": {"name": "Cream Linen Trousers", "slot": "trousers", "style": "suit", "color": Color("d9cfb6"), "price": 380, "desc": "Summer on the riviera."},
	"trousers_jeans": {"name": "Dark Denim Jeans", "slot": "trousers", "style": "jeans", "color": Color("1f2a44"), "price": 150, "desc": "Casual."},
	# waistcoats ----------------------------------------------------------
	"waistcoat_charcoal": {"name": "Charcoal Waistcoat", "slot": "waistcoat", "color": Color("2f2f38"), "price": 280, "desc": "Three-piece energy."},
	"waistcoat_burgundy": {"name": "Burgundy Waistcoat", "slot": "waistcoat", "color": Color("6a1a2b"), "price": 320, "desc": "Velvet back."},
	"waistcoat_gold": {"name": "Gold Brocade Waistcoat", "slot": "waistcoat", "color": Color("9a7a32"), "accent": Color("d9b25a"), "price": 600, "desc": "Loud money."},
	# coats ---------------------------------------------------------------
	"coat_trench_black": {"name": "Black Trench Coat", "slot": "coat", "style": "trench", "color": Color("121118"), "price": 1100, "desc": "Belted. The noir classic."},
	"coat_trench_midnight": {"name": "Midnight Trench Coat", "slot": "coat", "style": "trench", "color": Color("18204a"), "price": 1200, "desc": "Storm-proof gabardine."},
	"coat_over_camel": {"name": "Camel Overcoat", "slot": "coat", "style": "overcoat", "color": Color("9b7650"), "price": 1350, "desc": "Cashmere. Says 'I own the building'."},
	"coat_over_burgundy": {"name": "Burgundy Overcoat", "slot": "coat", "style": "overcoat", "color": Color("4f1120"), "price": 1500, "desc": "Wool, ankle length, unforgettable."},
	# ties ----------------------------------------------------------------
	"tie_black": {"name": "Black Silk Tie", "slot": "tie", "style": "tie", "color": Color("0e0d12"), "price": 0, "desc": "Funeral-ready."},
	"tie_burgundy": {"name": "Burgundy Tie", "slot": "tie", "style": "tie", "color": Color("7a1d31"), "price": 120, "desc": ""},
	"tie_gold": {"name": "Gold Satin Tie", "slot": "tie", "style": "tie", "color": Color("c9a24a"), "price": 150, "desc": ""},
	"tie_neon": {"name": "Neon Blue Skinny Tie", "slot": "tie", "style": "skinny", "color": Color("2d8cff"), "price": 140, "desc": "Catches the light."},
	"tie_bow": {"name": "Black Bow Tie", "slot": "tie", "style": "bow", "color": Color("0e0d12"), "price": 160, "desc": "For the casino."},
	# pocket squares ------------------------------------------------------
	"square_white": {"name": "White Pocket Square", "slot": "pocket_square", "color": Color("f0ede6"), "price": 60, "desc": ""},
	"square_red": {"name": "Crimson Pocket Square", "slot": "pocket_square", "color": Color("c0213c"), "price": 70, "desc": ""},
	"square_gold": {"name": "Gold Pocket Square", "slot": "pocket_square", "color": Color("d9b25a"), "price": 80, "desc": ""},
	# shoes ---------------------------------------------------------------
	"shoes_oxford_black": {"name": "Black Oxfords", "slot": "shoes", "style": "oxford", "color": Color("0d0c10"), "price": 0, "desc": "Mirror shine."},
	"shoes_oxford_brown": {"name": "Brown Brogues", "slot": "shoes", "style": "oxford", "color": Color("4a2a18"), "price": 400, "desc": "Hand-stitched."},
	"shoes_loafer": {"name": "Burgundy Loafers", "slot": "shoes", "style": "loafer", "color": Color("5a1424"), "price": 450, "desc": "Tassels optional."},
	"shoes_boots": {"name": "Black Chelsea Boots", "slot": "shoes", "style": "boot", "color": Color("121014"), "price": 380, "desc": "Built for rain."},
	"shoes_sneakers": {"name": "White Sneakers", "slot": "shoes", "style": "sneaker", "color": Color("e8e6e0"), "price": 200, "desc": "Quiet on concrete."},
	# gloves --------------------------------------------------------------
	"gloves_black": {"name": "Black Leather Gloves", "slot": "gloves", "color": Color("0f0e12"), "price": 220, "desc": "No fingerprints."},
	"gloves_brown": {"name": "Brown Driving Gloves", "slot": "gloves", "color": Color("5a3520"), "price": 190, "desc": ""},
	# hats ----------------------------------------------------------------
	"hat_fedora_black": {"name": "Black Fedora", "slot": "hat", "style": "fedora", "color": Color("121118"), "accent": Color("2a2733"), "price": 250, "desc": "Brim low. Eyes hidden."},
	"hat_fedora_grey": {"name": "Grey Fedora", "slot": "hat", "style": "fedora", "color": Color("4a4a52"), "accent": Color("15141c"), "price": 300, "desc": ""},
	"hat_trilby": {"name": "Burgundy Trilby", "slot": "hat", "style": "trilby", "color": Color("4f1120"), "accent": Color("c9a24a"), "price": 420, "desc": ""},
	"hat_flatcap": {"name": "Tweed Flat Cap", "slot": "hat", "style": "flatcap", "color": Color("4d4436"), "price": 180, "desc": "Dockside chic."},
	# eyewear -------------------------------------------------------------
	"glasses_aviator": {"name": "Gold Aviators", "slot": "glasses", "style": "aviator", "color": Color("c9a24a"), "price": 350, "desc": ""},
	"glasses_round": {"name": "Round Shades", "slot": "glasses", "style": "round", "color": Color("1a1a1a"), "price": 280, "desc": ""},
	"glasses_wayfarer": {"name": "Noir Wayfarers", "slot": "glasses", "style": "wayfarer", "color": Color("0c0c0c"), "price": 220, "desc": ""},
	# jewellery -----------------------------------------------------------
	"watch_steel": {"name": "Steel Chronograph", "slot": "watch", "color": Color("b8bec8"), "price": 900, "desc": ""},
	"watch_gold": {"name": "Gold Dress Watch", "slot": "watch", "color": Color("e0b34e"), "price": 2400, "desc": "Swiss. Heavy."},
	"watch_vintage": {"name": "Vintage Leather Watch", "slot": "watch", "color": Color("6b4428"), "price": 700, "desc": "His father's model."},
	"ring_signet": {"name": "Gold Signet Ring", "slot": "ring", "color": Color("e0b34e"), "price": 800, "desc": ""},
	"ring_silver": {"name": "Silver Band", "slot": "ring", "color": Color("c8ccd4"), "price": 300, "desc": ""},
	"necklace_gold": {"name": "Gold Chain", "slot": "necklace", "color": Color("e0b34e"), "price": 1100, "desc": "Best worn with an open collar."},
	"necklace_silver": {"name": "Silver Chain", "slot": "necklace", "color": Color("c8ccd4"), "price": 450, "desc": ""},
}

const STARTER_CLOTHES := ["suit_black", "trousers_black", "shirt_white", "tie_black", "shoes_oxford_black"]

# ---------------------------------------------------------------- items
const ITEMS := {
	"lockpick": {"name": "Lockpick Set", "kind": "Equipment", "desc": "Military-issue picks. Quiet and quick."},
	"burner_phone": {"name": "Burner Phone", "kind": "Equipment", "desc": "Vincent Moretti has this number. Nobody else should."},
	"ledger": {"name": "Castellano Ledger", "kind": "Key Item", "desc": "Leather-bound accounts. The Moretti name appears on page 41. Deliver it to Vincent."},
	"key_calloway": {"name": "Key — Calloway Apt 4B", "kind": "Key", "desc": "Your safehouse in the Velvet Quarter."},
	"matchbook": {"name": "Velvet Hour Matchbook", "kind": "Clue", "desc": "A phone number is written inside in red ink. Whose?"},
}

# ---------------------------------------------------------------- properties
const PROPERTIES := {
	"calloway_4b": {"name": "Calloway Building — Apt 4B", "district": "velvet", "price": 2000,
		"desc": "A fourth-floor walk-up with a view of the Velvet Quarter skyline. Rain on the windows, jazz through the floorboards."},
}

# ---------------------------------------------------------------- districts
const DISTRICTS := [
	{"id": "velvet", "name": "The Velvet Quarter", "family": "Contested — Moretti / Castellano",
		"desc": "Jazz clubs, old restaurants and neon. Where deals are made over dinner.", "music": "velvet"},
	{"id": "docks", "name": "Sable Docks", "family": "Volkov Syndicate",
		"desc": "Container cranes, fog and shipments nobody declares.", "music": "velvet"},
	{"id": "crown", "name": "Crown Heights", "family": "The Delacroix Group",
		"desc": "Glass towers, penthouses and city money.", "music": "velvet"},
	{"id": "palermo", "name": "Little Palermo", "family": "Moretti Family",
		"desc": "Moretti home turf. Bakeries, churches, back rooms.", "music": "velvet"},
	{"id": "neonmile", "name": "The Neon Mile", "family": "Kuroda-kai",
		"desc": "Casinos, nightclubs and the brightest lights in Nightcity.", "music": "velvet"},
	{"id": "ashgate", "name": "Ashgate", "family": "City Hall / NCPD",
		"desc": "Courthouse, cathedral and the police headquarters.", "music": "velvet"},
]

const MISSIONS := {
	"m01_ledger": {"name": "The Ledger", "giver": "Vincent Moretti", "reward": 3000,
		"desc": "Break into the Castellano bookkeeping office above the Sable Street laundromat and steal the ledger. Stay unseen."},
}

func clothing(id: String) -> Dictionary:
	return CLOTHES.get(id, {})

func items_for_slot(slot: String) -> Array:
	var out := []
	for id in CLOTHES.keys():
		if CLOTHES[id]["slot"] == slot:
			out.append(id)
	out.sort_custom(func(a, b): return CLOTHES[a]["price"] < CLOTHES[b]["price"])
	return out

func district(id: String) -> Dictionary:
	for d in DISTRICTS:
		if d["id"] == id:
			return d
	return {}
