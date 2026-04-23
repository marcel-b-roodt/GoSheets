## SpellMetadata
##
## Data-only Resource describing a single spell.
## Used as test data for GoSheets — covers the most common exported types:
##   String, int, float, bool, and an enum.
class_name SpellMetadata
extends Resource

## The element a spell belongs to.
enum Element {
	FIRE      = 0,
	ICE       = 1,
	LIGHTNING = 2,
	EARTH     = 3,
	WIND      = 4,
	ARCANE    = 5,
}

## Display name shown in UI and the spellbook.
@export var spell_name: String = ""
## Full flavour/mechanical description.
@export_multiline var description: String = ""
## Base mana cost to cast.
@export_range(0, 200, 1) var mana_cost: int = 0
## Seconds before the spell can be cast again.
@export_range(0.0, 30.0, 0.1) var cooldown: float = 1.0
## Elemental affinity.
@export var element: Element = Element.ARCANE
## Whether the player has unlocked this spell.
@export var is_unlocked: bool = true
