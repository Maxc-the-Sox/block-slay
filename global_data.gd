extends Node

var player_hp: int = 100
var player_max_hp: int = 100

# --- UNSER UNSICHTBARER RUCKSACK ---

# Hier speichern wir die kompletten Tetris-Blöcke (Farben und Positionen)
var tetris_grid = {}

# Hier merken wir uns, wo du Truhen und Monster platziert hast
var truhen_positionen = []
var monster_positionen = []
var tetris_doors = {}

# (Später können wir hier auch die Lebenspunkte und das Level des Spielers speichern!)
