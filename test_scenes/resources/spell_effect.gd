## SpellEffect
##
## Data-only Resource describing one effect entry used by a spell.

class_name SpellEffect
extends Resource

## Where this effect can be applied.
enum SpellRange {
	TOUCH = 0,
	TARGET = 1,
	SELF = 2,
}

## Effect display name.
@export var effect_name: String = ""
## Effect description/details.
@export_multiline var description: String = ""
## Effect application range.
@export var spell_range: SpellRange = SpellRange.TARGET
## Optional category for grouping/filtering.
@export var category: String = "General"
