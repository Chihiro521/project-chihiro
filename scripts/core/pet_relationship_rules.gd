class_name PetRelationshipRules
extends RefCounted

const TIERS := ["distant", "guarded", "familiar", "trusted", "close"]
const UP_THRESHOLDS := [0.0, 20.0, 40.0, 60.0, 80.0]
const DOWN_HYSTERESIS := 3.0
const DAILY_POSITIVE_CAP := 3.0
const DAILY_NEGATIVE_CAP := 3.0

const HEAD_PAT_REFUSAL := {
	"distant": 0.85,
	"guarded": 0.55,
	"familiar": 0.20,
	"trusted": 0.05,
	"close": 0.0,
}
const RAPID_POKE_THRESHOLDS := {
	"distant": 2,
	"guarded": 3,
	"familiar": 3,
	"trusted": 4,
	"close": 4,
}
const CONTROL_QUIP_PROBABILITIES := {
	"distant": 0.25,
	"guarded": 0.30,
	"familiar": 0.40,
	"trusted": 0.50,
	"close": 0.60,
}


static func normalize_tier(value: String) -> String:
	match value.strip_edges().to_lower():
		"distant", "estranged", "疏远": return "distant"
		"guarded", "wary", "戒备": return "guarded"
		"familiar", "熟悉": return "familiar"
		"trusted", "trust", "信任": return "trusted"
		"close", "intimate", "亲近": return "close"
		_: return "familiar"


static func relationship_rank(tier_id: String) -> int:
	return TIERS.find(normalize_tier(tier_id))


static func tier_for_affection(affection: float) -> String:
	var value := clampf(affection, 0.0, 100.0)
	var result := TIERS[0]
	for index in range(TIERS.size()):
		if value >= UP_THRESHOLDS[index]:
			result = TIERS[index]
	return result


static func tier_with_hysteresis(current_tier: String, affection: float) -> String:
	var current_rank := relationship_rank(current_tier)
	if current_rank < 0:
		return tier_for_affection(affection)
	var value := clampf(affection, 0.0, 100.0)
	var next_rank := current_rank
	while next_rank + 1 < TIERS.size() and value >= UP_THRESHOLDS[next_rank + 1]:
		next_rank += 1
	while next_rank > 0 and value < UP_THRESHOLDS[next_rank] - DOWN_HYSTERESIS:
		next_rank -= 1
	return TIERS[next_rank]


static func head_pat_refusal_probability(tier: String, irritation: float) -> float:
	if irritation >= 70.0:
		return 1.0
	var result := float(HEAD_PAT_REFUSAL.get(normalize_tier(tier), 0.20))
	if irritation >= 45.0:
		result = minf(0.95, result + 0.35)
	return result


static func rapid_poke_threshold(tier: String) -> int:
	return int(RAPID_POKE_THRESHOLDS.get(normalize_tier(tier), 3))


static func control_quip_probability(tier: String) -> float:
	return float(CONTROL_QUIP_PROBABILITIES.get(normalize_tier(tier), 0.40))


static func relationship_minimum_met(current_tier: String, minimum_tier: String) -> bool:
	return relationship_rank(current_tier) >= relationship_rank(minimum_tier)
