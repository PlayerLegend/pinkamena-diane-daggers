class_name MarkovChain
extends RefCounted
## Word-level Markov chain trained on a text file of newline-delimited passages.
##
## Usage:
##     var chain := MarkovChain.new(2)
##     chain.load_from_file("res://passages.txt")
##     var next := chain.get_next_word(["the", "quick"])
##     print(chain.generate(30))

## Number of words that make up one state.
var state_size: int = 2

## state key (words joined by a space) -> Array[String] of observed next words.
## Duplicates are kept on purpose so pick_random() is frequency-weighted.
## An empty string "" entry means "the passage ended after this state".
var _transitions: Dictionary = {}

## Array of state keys that began a passage (used by generate()).
var _starts: Array[String] = []

var _word_regex: RegEx


func _init(p_state_size: int = 2) -> void:
    state_size = maxi(1, p_state_size)
    _word_regex = RegEx.new()
    _word_regex.compile("\\S+")


## Loads a file where each line is one passage and trains on it.
## Clears any previous training data. Returns OK or a FileAccess error.
func load_from_file(path: String) -> Error:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return FileAccess.get_open_error()

    clear()
    while not file.eof_reached():
        train_passage(file.get_line())
    return OK


## Removes all trained data.
func clear() -> void:
    _transitions.clear()
    _starts.clear()


## Adds a single passage to the model.
func train_passage(passage: String) -> void:
    var words := _tokenize(passage)
    if words.size() < state_size:
        return

    _starts.append(_make_key(words.slice(0, state_size)))

    for i in range(words.size() - state_size + 1):
        var key := _make_key(words.slice(i, i + state_size))
        var next_word := ""  # "" marks end of passage
        if i + state_size < words.size():
            next_word = words[i + state_size]

        if not _transitions.has(key):
            _transitions[key] = []
        _transitions[key].append(next_word)


## Returns a (frequency-weighted) random next word for the given words.
## Only the last `state_size` words of word_array are used.
## Returns "" if the state is unknown, word_array is too short,
## or the state was only ever seen at the end of a passage.
func get_next_word(word_array: Array) -> String:
    if word_array.size() < state_size:
        return ""

    var state := word_array.slice(word_array.size() - state_size)
    var key := _make_key(state)
    if not _transitions.has(key):
        return ""

    var options: Array = _transitions[key]
    return options.pick_random()


## Convenience: builds a sentence starting from a random passage start,
## stopping at max_words or when a passage end is reached.
func generate(max_words: int = 50) -> String:
    if _starts.is_empty():
        return ""

    var words: Array = Array(_starts.pick_random().split(" "))
    while words.size() < max_words:
        var next := get_next_word(words)
        if next.is_empty():
            break
        words.append(next)
    return " ".join(PackedStringArray(words))


## True if the model has been trained on at least one usable passage.
func is_trained() -> bool:
    return not _transitions.is_empty()


func _tokenize(text: String) -> Array:
    var words: Array = []
    for m in _word_regex.search_all(text):
        words.append(m.get_string())
    return words


func _make_key(words: Array) -> String:
    return " ".join(PackedStringArray(words))
