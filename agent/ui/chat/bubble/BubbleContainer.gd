@abstract
class_name BubbleContainer
extends PanelContainer

## Base control for transcript bubbles. Subclasses own their UI and refresh behavior.

@abstract
func refresh(entry: ChatEntry) -> void
