## Player
##
## Stub player character for the GoSheets test scene.
## Holds a Spellbook resource so the resource graph can be explored.
class_name Player
extends CharacterBody2D

## The player's equipped spellbook.
@export var spellbook: Spellbook

## Active spell index into spellbook.spells.
@export var active_spell_index: int = 0
