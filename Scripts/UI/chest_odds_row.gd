## How likely a hero chest roll lands on each rarity: a rarity-colored swatch
## and a percentage per rarity that has heroes (from CampaignConfig). Builds
## itself; drop it anywhere.
##
## Dependencies: GameConfig, CampaignConfig, HeroData
class_name ChestOddsRow
extends HBoxContainer

@export var swatch_size: float = 20.0


func _ready() -> void:
	add_theme_constant_override("separation", 18)
	var campaign: CampaignConfig = GameConfig.get_default().campaign
	for rarity: int in HeroData.Rarity.values():
		var chance: float = campaign.get_chest_rarity_chance(rarity as HeroData.Rarity)
		if chance <= 0.0:
			continue
		var swatch: ColorRect = ColorRect.new()
		swatch.color = HeroData.RARITY_COLORS[rarity]
		swatch.custom_minimum_size = Vector2.ONE * swatch_size
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chance_label: Label = Label.new()
		chance_label.theme_type_variation = &"SmallLabel"
		chance_label.text = "%d%%" % roundi(chance * 100.0)
		var odds_item: HBoxContainer = HBoxContainer.new()
		odds_item.add_theme_constant_override("separation", 6)
		odds_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		odds_item.add_child(swatch)
		odds_item.add_child(chance_label)
		add_child(odds_item)
