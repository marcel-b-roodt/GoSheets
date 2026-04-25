## Spellbook
##
## A collection of SpellMetadata resources carried by a character.
## The [member spells] array holds references to individual spell assets.
class_name Spellbook
extends Resource

## Name of the character who owns this spellbook.
@export var owner_name: String = ""
## Maximum number of spells that can be held.
@export var max_spells: int = 8
## All spells currently in this book.
@export var spells: Array[SpellMetadata] = []
