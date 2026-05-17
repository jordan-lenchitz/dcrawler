import random
import os

DUNGEON_ROWS = 20
DUNGEON_COLS = 60
OUTPUT_DIR = "txt"
NUM_DUNGEONS = 99

GLYPHS = {
    "wall": '#',
    "floor": ' ',
    "void": '.',
    "door_closed": '+',
    "door_open": '/',
    "enemy": ['g', 'r', 'b'],
    "trap": ['^', '~'],
    "item": ['!', '(', '$'],
    "player_start": '@',
    "exit": '>',
}

def generate_dungeon():
    grid = [[GLYPHS["void"] for _ in range(DUNGEON_COLS)] for _ in range(DUNGEON_ROWS)]

    # Place outer walls
    for c in range(DUNGEON_COLS):
        grid[0][c] = GLYPHS["wall"]
        grid[DUNGEON_ROWS - 1][c] = GLYPHS["wall"]
    for r in range(DUNGEON_ROWS):
        grid[r][0] = GLYPHS["wall"]
        grid[r][DUNGEON_COLS - 1] = GLYPHS["wall"]

    # Generate a few rooms
    num_rooms = random.randint(2, 5)
    floor_coords = []
    for _ in range(num_rooms):
        r1 = random.randint(2, DUNGEON_ROWS - 7)
        c1 = random.randint(2, DUNGEON_COLS - 7)
        r2 = random.randint(r1 + 3, DUNGEON_ROWS - 2)
        c2 = random.randint(c1 + 5, DUNGEON_COLS - 2)

        for r in range(r1, r2 + 1):
            for c in range(c1, c2 + 1):
                if 0 < r < DUNGEON_ROWS -1 and 0 < c < DUNGEON_COLS - 1: # Stay within bounds
                    grid[r][c] = GLYPHS["floor"]
                    floor_coords.append((r, c))

    # Add features (items, enemies, traps)
    for _ in range(random.randint(5, 15)): # Items
        if floor_coords:
            r, c = random.choice(floor_coords)
            grid[r][c] = random.choice(GLYPHS["item"])
    
    for _ in range(random.randint(3, 8)): # Enemies
        if floor_coords:
            r, c = random.choice(floor_coords)
            grid[r][c] = random.choice(GLYPHS["enemy"])
            
    for _ in range(random.randint(2, 6)): # Traps
        if floor_coords:
            r, c = random.choice(floor_coords)
            grid[r][c] = random.choice(GLYPHS["trap"])

    # Place player and exit ensuring they are on a floor or empty space
    player_placed = False
    exit_placed = False

    attempts = 0
    while not player_placed and attempts < 1000:
        r = random.randint(1, DUNGEON_ROWS - 2)
        c = random.randint(1, DUNGEON_COLS - 2)
        if grid[r][c] == GLYPHS["floor"] or grid[r][c] == GLYPHS["void"]:
            grid[r][c] = GLYPHS["player_start"]
            player_placed = True
        attempts += 1
    
    attempts = 0
    while not exit_placed and attempts < 1000:
        r = random.randint(1, DUNGEON_ROWS - 2)
        c = random.randint(1, DUNGEON_COLS - 2)
        if (grid[r][c] == GLYPHS["floor"] or grid[r][c] == GLYPHS["void"]) and grid[r][c] != GLYPHS["player_start"]:
            grid[r][c] = GLYPHS["exit"]
            exit_placed = True
        attempts += 1

    return ["".join(row) for row in grid]

# Main generation loop
output_path = os.path.join("dcrawler", OUTPUT_DIR)
os.makedirs(output_path, exist_ok=True)

for i in range(1, NUM_DUNGEONS + 1):
    dungeon_data = generate_dungeon()
    file_name = os.path.join(output_path, f"dungeon_{i}.txt")
    with open(file_name, "w") as f:
        for row in dungeon_data:
            f.write(row + "\x0A") # THIS IS THE CORRECT LINE I WANT IN THE FILE
    print(f"Generated {file_name}")

print(f"Generated {NUM_DUNGEONS} dungeons in {output_path}")
