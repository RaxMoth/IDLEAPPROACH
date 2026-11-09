## Number and time formatting for UI (idle-game friendly short numbers).
##
##   NumberFormat.compact(1530)        -> "1.53K"
##   NumberFormat.compact(4.5e36)      -> "4.5aa"   (idle-scale: aa, ab ... zz after Dc)
##   NumberFormat.with_separators(1234567) -> "1,234,567"
##   NumberFormat.duration(125)        -> "2:05"
##
## Dependencies: none
class_name NumberFormat
extends RefCounted

const SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]
const LETTER_COUNT: int = 26


static func compact(value: float, decimals: int = 2) -> String:
	var absolute_value: float = absf(value)
	if is_inf(value) or is_nan(value):
		return "∞"
	if absolute_value < 1000.0:
		return str(int(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)
	var suffix_index: int = int(floor(log(absolute_value) / log(1000.0)))
	var shown_decimals: int = _get_shown_decimals(value / pow(1000.0, suffix_index), decimals)
	var rounded_value: float = snappedf(value / pow(1000.0, suffix_index), pow(10.0, -shown_decimals))
	# Rounding (or float log error) can reach 1000 of a suffix (999,999 -> "1000K") — carry to the next one.
	if absf(rounded_value) >= 1000.0:
		suffix_index += 1
		shown_decimals = _get_shown_decimals(value / pow(1000.0, suffix_index), decimals)
		rounded_value = snappedf(value / pow(1000.0, suffix_index), pow(10.0, -shown_decimals))
	# String.num keeps a ".0" on whole numbers; "1M" reads cleaner than "1.0M".
	var number_text: String = str(int(rounded_value)) if is_equal_approx(rounded_value, roundf(rounded_value)) else String.num(rounded_value, shown_decimals)
	return number_text + get_suffix(suffix_index)


## Fewer decimals for larger leading numbers keeps the width stable: 1.23K, 12.3K, 123K.
static func _get_shown_decimals(scaled_value: float, max_decimals: int) -> int:
	var leading_digits: int = str(int(absf(scaled_value))).length()
	return clampi(max_decimals + 1 - leading_digits, 0, max_decimals)


## Suffix for 1000^[param suffix_index]: named ones first (K, M ... Dc), then aa, ab ... zz.
static func get_suffix(suffix_index: int) -> String:
	if suffix_index < SUFFIXES.size():
		return SUFFIXES[suffix_index]
	var letter_index: int = mini(suffix_index - SUFFIXES.size(), LETTER_COUNT * LETTER_COUNT - 1)
	var first_letter: String = String.chr("a".unicode_at(0) + floori(float(letter_index) / LETTER_COUNT))
	var second_letter: String = String.chr("a".unicode_at(0) + letter_index % LETTER_COUNT)
	return first_letter + second_letter


static func with_separators(value: int, separator: String = ",") -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	var digit_count: int = digits.length()
	for digit_index: int in digit_count:
		if digit_index > 0 and (digit_count - digit_index) % 3 == 0:
			grouped += separator
		grouped += digits[digit_index]
	return ("-" if value < 0 else "") + grouped


## "m:ss" below an hour, "h:mm:ss" above.
static func duration(total_seconds: float) -> String:
	var whole_seconds: int = maxi(0, int(total_seconds))
	var hours: int = floori(whole_seconds / 3600.0)
	var minutes: int = floori((whole_seconds % 3600) / 60.0)
	var seconds: int = whole_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, seconds]
	return "%d:%02d" % [minutes, seconds]


## Human friendly "2h 5m" / "45s" style durations for timers like energy refills.
static func duration_short(total_seconds: float) -> String:
	var whole_seconds: int = maxi(0, int(total_seconds))
	if whole_seconds >= 3600:
		return "%dh %dm" % [floori(whole_seconds / 3600.0), floori((whole_seconds % 3600) / 60.0)]
	if whole_seconds >= 60:
		return "%dm %ds" % [floori(whole_seconds / 60.0), whole_seconds % 60]
	return "%ds" % whole_seconds
