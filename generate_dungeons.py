import random
import os
from collections import deque

DUNGEON_ROWS = 20
DUNGEON_COLS = 60
OUTPUT_DIR = "txt"
NUM_DUNGEONS = 5 # default to 5 dungeons for more variety

GLYPHS = {
    "player_start": '@',
    "wall": '#',
    "void": '.',
    "floor": ' ',
    "closed_door": '+',
    "open_door": '/',
    "enemies": ['g', 'r', 'b'],
    "spike_trap": '^',
    "poison_tile": '~',
    "potion": '!',
    "key": '(',
    "gold": '$',
    "exit": '>',
}

def is_within_bounds(r, c):
    return 0 < r < DUNGEON_ROWS - 1 and 0 < c < DUNGEON_COLS - 1 # Exclude outer walls

def get_neighbors(r, c):
    """Returns valid neighbors (up, down, left, right) for a given coordinate."""
    neighbors = []
    for dr, dc in [(0, 1), (0, -1), (1, 0), (-1, 0)]: # Right, Left, Down, Up
        nr, nc = r + dr, c + dc
        if is_within_bounds(nr, nc):
            neighbors.append((nr, nc))
    return neighbors

def is_connected(grid, start_coords, target_coords, traversable_glyphs):
    """
    Performs a BFS to check if target_coords are reachable from start_coords
    through traversable_glyphs.
    """
    if not start_coords or not target_coords:
        return True # Or handle as error/special case

    q = deque([start_coords])
    visited = {start_coords}
    
    while q:
        r, c = q.popleft()
        if (r, c) == target_coords:
            return True

        for nr, nc in get_neighbors(r, c):
            if (nr, nc) not in visited and grid[nr][nc] in traversable_glyphs: # Changed to check if glyph is traversable
                visited.add((nr, nc))
                q.append((nr, nc))
                
    return False

def place_feature_in_coords(grid, feature_glyph, valid_coords, exclude_coords=[]):
    """Places a single feature within a list of valid coordinates, avoiding exclude_coords."""
    possible_spots = [coord for coord in valid_coords if coord not in exclude_coords and grid[coord[0]][coord[1]] == GLYPHS["floor"]]
    
    if not possible_spots:
        return None # No place to put it

    r, c = random.choice(possible_spots)
    grid[r][c] = feature_glyph
    return (r, c)

def generate_dungeon():
    grid = [[GLYPHS["wall"] for _ in range(DUNGEON_COLS)] for _ in range(DUNGEON_ROWS)]
    
    critical_path_coords = [] # Store coords of player, exit, key, door

    # 1. Initialize Grid with Walls, then Flood Fill with Floor
    # Start flood fill from a random central point
    start_r = random.randint(3, DUNGEON_ROWS - 4)
    start_c = random.randint(3, DUNGEON_COLS - 4)
    
    q = deque([(start_r, start_c)])
    grid[start_r][start_c] = GLYPHS["floor"]
    floor_tiles = [(start_r, start_c)]
    
    # Fill a large percentage of the dungeon with floor
    target_floor_count = int((DUNGEON_ROWS - 2) * (DUNGEON_COLS - 2) * random.uniform(0.75, 0.85))

    while q and len(floor_tiles) < target_floor_count:
        r, c = q.popleft()

        for nr, nc in get_neighbors(r, c):
            if grid[nr][nc] == GLYPHS["wall"]: # Only turn walls into floor
                grid[nr][nc] = GLYPHS["floor"]
                floor_tiles.append((nr, nc))
                q.append((nr, nc))
    
    # If the flood fill didn't reach the target, force more floor
    while len(floor_tiles) < target_floor_count: # Fallback to ensure density
        r, c = random.randint(1, DUNGEON_ROWS - 2), random.randint(1, DUNGEON_COLS - 2)
        if grid[r][c] == GLYPHS["wall"]:
            grid[r][c] = GLYPHS["floor"]
            floor_tiles.append((r,c))


    # 2. Place Critical Elements
    available_floor_tiles = list(floor_tiles) # Copy for modifications

    # Player Start
    player_coords = (start_r, start_c)
    player_r, player_c = player_coords # Unpack coords
    grid[player_r][player_c] = GLYPHS["player_start"]
    critical_path_coords.append(player_coords)
    if player_coords in available_floor_tiles: available_floor_tiles.remove(player_coords)


    # Exit - ensure sufficient distance
    exit_coords = None
    attempts = 0
    while not exit_coords and attempts < 1000:
        if not available_floor_tiles: break # No place to put exit
        candidate_exit = random.choice(available_floor_tiles)
        if abs(candidate_exit[0] - player_coords[0]) + abs(candidate_exit[1] - player_coords[1]) > (DUNGEON_ROWS + DUNGEON_COLS) // 4:
            exit_coords = candidate_exit
        attempts += 1
    
    if exit_coords:
        grid[exit_coords[0]][exit_coords[1]] = GLYPHS["exit"]
        critical_path_coords.append(exit_coords)
        if exit_coords in available_floor_tiles: available_floor_tiles.remove(exit_coords)
    else: # Fallback: just place it somewhere if distance criteria is too hard
        if available_floor_tiles: # Only if there are still floor tiles
            exit_coords = random.choice(available_floor_tiles)
            grid[exit_coords[0]][exit_coords[1]] = GLYPHS["exit"]
            critical_path_coords.append(exit_coords)
            if exit_coords in available_floor_tiles: available_floor_tiles.remove(exit_coords)


    # Door and Key
    door_coords = None
    key_coords = None
    attempts = 0
    while not door_coords and attempts < 1000:
        if not available_floor_tiles: break # No place for door
        candidate_door_spot = random.choice(available_floor_tiles)
        
        # Look for an adjacent wall to place the door into
        potential_door_wall = None
        for nr, nc in get_neighbors(candidate_door_spot[0], candidate_door_spot[1]):
            if grid[nr][nc] == GLYPHS["wall"]:
                potential_door_wall = (nr, nc)
                break
        
        if potential_door_wall:
            grid[potential_door_wall[0]][potential_door_wall[1]] = GLYPHS["closed_door"]
            door_coords = potential_door_wall
            critical_path_coords.append(door_coords)
            if candidate_door_spot in available_floor_tiles: available_floor_tiles.remove(candidate_door_spot) # Remove spot if door is effectively "on" it
            break
        attempts += 1
    
    # Place Key
    if door_coords:
        # Place key on the side of the door that allows access from player start (heuristic)
        # For simplicity, just place key on any available floor, but not too close to the door
        key_spots = [coord for coord in available_floor_tiles if abs(coord[0] - door_coords[0]) + abs(coord[1] - door_coords[1]) > 5]
        if key_spots:
            key_coords = random.choice(key_spots)
            grid[key_coords[0]][key_coords[1]] = GLYPHS["key"]
            critical_path_coords.append(key_coords)
            if key_coords in available_floor_tiles: available_floor_tiles.remove(key_coords)
        else: # Fallback
            key_coords = random.choice(available_floor_tiles)
            grid[key_coords[0]][key_coords[1]] = GLYPHS["key"]
            critical_path_coords.append(key_coords)
            if key_coords in available_floor_tiles: available_floor_tiles.remove(key_coords)
    

    # 3. Sparse Wall Placement
    # Place a very small number of walls to add structure, but preserve connectivity
    num_walls_to_place = int(len(floor_tiles) * 0.05) # 5% of floor tiles converted to wall
    for _ in range(num_walls_to_place):
        if not available_floor_tiles: break
        
        candidate_wall_spot = random.choice(available_floor_tiles)
        r, c = candidate_wall_spot
        
        # Temporarily place wall to test connectivity
        original_glyph = grid[r][c]
        grid[r][c] = GLYPHS["wall"]

        # Check connectivity: player to exit, key to door (if they exist)
        connected_after_wall = True
        if player_coords and exit_coords:
            if not is_connected(grid, player_coords, exit_coords, [GLYPHS["floor"], GLYPHS["closed_door"]]):
                connected_after_wall = False
        if key_coords and door_coords:
             if not is_connected(grid, key_coords, door_coords, [GLYPHS["floor"]]): # Key path should not cross door
                connected_after_wall = False

        if connected_after_wall:
            critical_path_coords.append((r,c)) # Keep the wall
            available_floor_tiles.remove(candidate_wall_spot)
        else:
            grid[r][c] = original_glyph # Revert if connectivity is broken


    # 4. Populate Other Features (enemies, potions, gold, traps)
    # Ensure features don't overwrite critical path elements or walls
    final_available_spots = [coord for coord in available_floor_tiles if grid[coord[0]][coord[1]] == GLYPHS["floor"] and coord not in critical_path_coords]


    for _ in range(random.randint(3, 6)): # Potions
        if final_available_spots:
            r, c = random.choice(final_available_spots)
            grid[r][c] = GLYPHS["potion"]
            final_available_spots.remove((r,c))
            
    for _ in range(random.randint(5, 10)): # Gold
        if final_available_spots:
            r, c = random.choice(final_available_spots)
            grid[r][c] = GLYPHS["gold"]
            final_available_spots.remove((r,c))

    for enemy_glyph in GLYPHS["enemies"]: # Enemies
        for _ in range(random.randint(1, 3)):
            if final_available_spots:
                r, c = random.choice(final_available_spots)
                grid[r][c] = enemy_glyph
                final_available_spots.remove((r,c))

    for trap_glyph in [GLYPHS["spike_trap"], GLYPHS["poison_tile"]]: # Traps
        for _ in range(random.randint(1, 3)):
            if final_available_spots:
                r, c = random.choice(final_available_spots)
                grid[r][c] = trap_glyph
                final_available_spots.remove((r,c))


    return ["".join(row) for row in grid]

# Main generation loop
output_path = OUTPUT_DIR
os.makedirs(output_path, exist_ok=True)

for i in range(1, NUM_DUNGEONS + 1):
    dungeon_data = generate_dungeon()
    file_name = os.path.join(output_path, f"dungeon_{i}.txt")
    with open(file_name, "w") as f:
        for row in dungeon_data:
            f.write(row)
            f.write("\x0A")
    print(f"Generated {file_name}")

print(f"Generated {NUM_DUNGEONS} dungeon(s) in {output_path}")
