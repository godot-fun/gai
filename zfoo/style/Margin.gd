class_name Margin
extends Object

## Spacing helpers for modifying the padding and margin of an element.
##
## Values follow a 4px step scale, e.g. [code]Margin.ma_4[/code] == 16. The constants are ints
## because that is what theme constants ask for; the float size properties (`content_margin_*`,
## offsets, custom minimum size) take them as-is, since int to float is a lossless conversion.
## All four sides of a box at once go through [method StyleBoxHelper.apply_margin].
## Typical use:
## [codeblock]
## var margin := MarginContainer.new()
## margin.add_theme_constant_override("margin_left", Margin.ma_4)
## margin.add_theme_constant_override("margin_right", Margin.ma_4)
##
## var style := StyleBoxFlat.new()
## style.content_margin_left = Margin.ma_4
## style.content_margin_right = Margin.ma_4
## [/codeblock]

const ma_0: int = 0
const ma_1: int = 4
const ma_2: int = 8
const ma_3: int = 12
const ma_4: int = 16
const ma_5: int = 20
const ma_6: int = 24
const ma_7: int = 28
const ma_8: int = 32
const ma_9: int = 36
const ma_10: int = 40
const ma_11: int = 44
const ma_12: int = 48
const ma_13: int = 52
const ma_14: int = 56
const ma_15: int = 60
const ma_16: int = 64
