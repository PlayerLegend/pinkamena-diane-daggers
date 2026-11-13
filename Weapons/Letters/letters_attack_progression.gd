class_name LettersAttackProgression
extends Resource

@export var levels: Array[LettersAttackType] = []

func get_attack_type(score: int) -> LettersAttackType:
    var best = null
    var best_score: int = 0
    for level in levels:
        if level.score_threshold > score:
            continue
        if best_score <= level.score_threshold:
            best_score = level.score_threshold
            best = level
    return best
        
