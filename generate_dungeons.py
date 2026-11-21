import argparse
import os
import random
from collections import deque

DUNGEON_ROWS = 20
DUNGEON_COLS = 60
OUTPUT_DIR = "txt"
NUM_DUNGEONS = 25

GLYPHS = {
    "player_start": "@",
    "wall": "#",
    "void": ".",
    "floor": " ",
    "closed_door": "+",
    "open_door": "/",
    "enemies": ["g", "r", "b"],
    "spike_trap": "^",
    "poison_tile": "~",
    "potion": "!",
    "meat": "M",
    "apple": "A",
    "bread": "B",
    "tofu": "T",
    "key": "(",
    "gold": "$",
    "dagger": ")",
    "sword": "}",
    "exit": ">",
}


class Room:
    def __init__(self, r, c, h, w):
        self.r = r
        self.c = c
        self.h = h
        self.w = w

    @property
    def center(self):
        return (self.r + self.h // 2, self.c + self.w // 2)

    def intersects(self, other, pad=2):
        return not (
            self.r + self.h + pad <= other.r
            or other.r + other.h + pad <= self.r
            or self.c + self.w + pad <= other.c
            or other.c + other.w + pad <= self.c
        )

    def cells(self):
        return [
            (rr, cc)
            for rr in range(self.r, self.r + self.h)
            for cc in range(self.c, self.c + self.w)
        ]


def neighbors4(r, c):
    for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        nr, nc = r + dr, c + dc
        if 0 <= nr < DUNGEON_ROWS and 0 <= nc < DUNGEON_COLS:
            yield nr, nc


def bfs_reachable(grid, start, passable):
    q = deque([start])
    visited = {start}
    while q:
        r, c = q.popleft()
        for nr, nc in neighbors4(r, c):
            if (nr, nc) not in visited and grid[nr][nc] in passable:
                visited.add((nr, nc))
                q.append((nr, nc))
    return visited


def carve_room(grid, room):
    for r, c in room.cells():
        grid[r][c] = GLYPHS["floor"]


def carve_corridor(grid, p1, p2, rng):
    r1, c1 = p1
    r2, c2 = p2
    path = []
    if rng.random() < 0.5:
        step = 1 if c2 >= c1 else -1
        for c in range(c1, c2 + step, step):
            path.append((r1, c))
        step = 1 if r2 >= r1 else -1
        for r in range(r1, r2 + step, step):
            path.append((r, c2))
    else:
        step = 1 if r2 >= r1 else -1
        for r in range(r1, r2 + step, step):
            path.append((r, c1))
        step = 1 if c2 >= c1 else -1
        for c in range(c1, c2 + step, step):
            path.append((r2, c))
    for r, c in path:
        grid[r][c] = GLYPHS["floor"]
    return path


def wrap_walls(grid):
    for r in range(DUNGEON_ROWS):
        for c in range(DUNGEON_COLS):
            if grid[r][c] == GLYPHS["void"]:
                has_floor = False
                for dr in (-1, 0, 1):
                    for dc in (-1, 0, 1):
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < DUNGEON_ROWS and 0 <= nc < DUNGEON_COLS:
                            if grid[nr][nc] == GLYPHS["floor"]:
                                has_floor = True
                                break
                    if has_floor:
                        break
                if has_floor:
                    grid[r][c] = GLYPHS["wall"]


def try_generate_dungeon(floor, rng):
    grid = [[GLYPHS["void"] for _ in range(DUNGEON_COLS)] for _ in range(DUNGEON_ROWS)]
    target_rooms = min(8, 5 + floor // 2)
    rooms = []
    for _ in range(200):
        if len(rooms) >= target_rooms:
            break
        h = rng.randint(4, 6)
        w = rng.randint(6, 12)
        r = rng.randint(2, DUNGEON_ROWS - h - 2)
        c = rng.randint(2, DUNGEON_COLS - w - 2)
        cand = Room(r, c, h, w)
        if not any(cand.intersects(other, pad=2) for other in rooms):
            rooms.append(cand)
            carve_room(grid, cand)

    if len(rooms) < 4:
        return None

    # Pick start room (leftmost-ish) and exit room (farthest from start)
    start_room = min(rooms, key=lambda rm: rm.center[1] + rng.uniform(-4, 4))
    exit_room = max(
        [rm for rm in rooms if rm is not start_room],
        key=lambda rm: abs(rm.center[0] - start_room.center[0])
        + abs(rm.center[1] - start_room.center[1]),
    )
    main_rooms = [rm for rm in rooms if rm is not exit_room]

    # Connect all non-exit rooms via nearest-neighbor spanning tree
    connected = [start_room]
    remaining = [rm for rm in main_rooms if rm is not start_room]
    while remaining:
        best_pair = None
        best_d = 10**9
        for a in connected:
            for b in remaining:
                d = abs(a.center[0] - b.center[0]) + abs(a.center[1] - b.center[1])
                if d < best_d:
                    best_d = d
                    best_pair = (a, b)
        a, b = best_pair
        carve_corridor(grid, a.center, b.center, rng)
        connected.append(b)
        remaining.remove(b)

    # Optionally add one extra loop among main rooms for interesting navigation
    if len(main_rooms) >= 4:
        a, b = rng.sample(main_rooms, 2)
        carve_corridor(grid, a.center, b.center, rng)

    # Connect exit room via a single bridge corridor from its nearest main room
    nearest_to_exit = min(
        main_rooms,
        key=lambda rm: abs(rm.center[0] - exit_room.center[0])
        + abs(rm.center[1] - exit_room.center[1]),
    )
    exit_cells = set(exit_room.cells())
    main_cells = set()
    for rm in main_rooms:
        main_cells.update(rm.cells())

    bridge_path = carve_corridor(grid, nearest_to_exit.center, exit_room.center, rng)
    wrap_walls(grid)

    player_pos = start_room.center
    exit_pos = exit_room.center

    # Place closed door '+' on a bridge corridor tile outside both rooms that separates @ from >
    door_pos = None
    bridge_candidates = [
        p for p in reversed(bridge_path) if p not in exit_cells and p not in main_cells
    ]
    for cand in bridge_candidates:
        r, c = cand
        # Prefer a clean doorway chokepoint (walls on two opposite sides)
        horiz_choke = grid[r - 1][c] == "#" and grid[r + 1][c] == "#"
        vert_choke = grid[r][c - 1] == "#" and grid[r][c + 1] == "#"
        if not (horiz_choke or vert_choke):
            continue
        grid[r][c] = GLYPHS["closed_door"]
        reach_no_door = bfs_reachable(grid, player_pos, {GLYPHS["floor"]})
        reach_with_door = bfs_reachable(
            grid, player_pos, {GLYPHS["floor"], GLYPHS["closed_door"]}
        )
        if exit_pos not in reach_no_door and exit_pos in reach_with_door:
            door_pos = cand
            break
        grid[r][c] = GLYPHS["floor"]

    if door_pos is None:
        return None

    # Guaranteed reachable tiles on the player's side of the locked door
    reach_no_door = bfs_reachable(grid, player_pos, {GLYPHS["floor"]})
    grid[player_pos[0]][player_pos[1]] = GLYPHS["player_start"]
    grid[exit_pos[0]][exit_pos[1]] = GLYPHS["exit"]

    # Place key in a reachable non-start room (prefer farthest reachable floor cell from door)
    key_candidates = [
        p
        for p in reach_no_door
        if p != player_pos and p in main_cells and grid[p[0]][p[1]] == GLYPHS["floor"]
    ]
    if not key_candidates:
        return None
    non_start_keys = [p for p in key_candidates if p not in set(start_room.cells())]
    pool = non_start_keys if non_start_keys else key_candidates
    key_pos = rng.choice(pool)
    grid[key_pos[0]][key_pos[1]] = GLYPHS["key"]

    # Collect remaining floor tiles inside rooms/corridors (avoiding start cell and immediate adjacency to door)
    used = {player_pos, exit_pos, door_pos, key_pos}
    room_spots = [
        p
        for rm in rooms
        for p in rm.cells()
        if p not in used and grid[p[0]][p[1]] == GLYPHS["floor"]
    ]
    safe_start_spots = [
        p
        for p in room_spots
        if abs(p[0] - player_pos[0]) + abs(p[1] - player_pos[1]) > 2
    ]
    rng.shuffle(room_spots)
    rng.shuffle(safe_start_spots)

    def pop_spot(pool_list):
        while pool_list:
            p = pool_list.pop()
            if p not in used and grid[p[0]][p[1]] == GLYPHS["floor"]:
                used.add(p)
                return p
        return None

    # Weapon spawn scaled by floor (dagger on floors 1-6, sword on floors 7-25)
    weapon_glyph = GLYPHS["dagger"] if floor <= 6 else GLYPHS["sword"]
    # Place weapon on player side of door so it's useful before the final room
    weapon_pool = [p for p in room_spots if p in reach_no_door and p not in used]
    if weapon_pool:
        wp = rng.choice(weapon_pool)
        used.add(wp)
        grid[wp[0]][wp[1]] = weapon_glyph

    # Healing potions & vegan foods
    num_potions = rng.randint(2, 3)
    for _ in range(num_potions):
        p = pop_spot(room_spots)
        if p:
            grid[p[0]][p[1]] = GLYPHS["potion"]

    food_pool = (
        ["apple", "bread"]
        if floor <= 6
        else (["bread", "meat", "tofu"] if floor <= 15 else ["meat", "tofu"])
    )
    for _ in range(rng.randint(2, 4)):
        p = pop_spot(room_spots)
        if p:
            grid[p[0]][p[1]] = GLYPHS[rng.choice(food_pool)]

    # Gold
    for _ in range(rng.randint(4 + floor // 4, min(16, 6 + floor // 2))):
        p = pop_spot(room_spots)
        if p:
            grid[p[0]][p[1]] = GLYPHS["gold"]

    # Enemies scaled by floor (never spawn right next to player start)
    num_enemies = min(15, 2 + floor // 2)
    enemy_weights = (
        ["r", "r", "b", "g"]
        if floor <= 6
        else (["r", "b", "g", "g"] if floor <= 15 else ["b", "g", "g", "g"])
    )
    for _ in range(num_enemies):
        p = pop_spot(safe_start_spots)
        if p:
            grid[p[0]][p[1]] = rng.choice(enemy_weights)

    # Traps scaled by floor (keep clear of start room center and doorway)
    trap_spots = [
        p
        for p in safe_start_spots
        if abs(p[0] - door_pos[0]) + abs(p[1] - door_pos[1]) > 1
    ]
    for _ in range(min(12, 1 + floor // 2)):
        p = pop_spot(trap_spots)
        if p:
            grid[p[0]][p[1]] = rng.choice([GLYPHS["spike_trap"], GLYPHS["poison_tile"]])

    return ["".join(row) for row in grid]


def generate_dungeon(floor=1, rng=None):
    if rng is None:
        rng = random.Random()
    for _ in range(200):
        res = try_generate_dungeon(floor, rng)
        if res is not None:
            return res
    raise RuntimeError(f"Failed to generate connected dungeon for floor {floor}")


def main():
    parser = argparse.ArgumentParser(description="Generate room-and-corridor dungeons for dcrawler.")
    parser.add_argument("--floors", type=int, default=NUM_DUNGEONS, help="Number of floors to generate")
    parser.add_argument("--out", default=OUTPUT_DIR, help="Output directory")
    parser.add_argument("--seed", type=int, default=None, help="Optional RNG seed")
    args = parser.parse_args()

    rng = random.Random(args.seed)
    os.makedirs(args.out, exist_ok=True)
    for i in range(1, args.floors + 1):
        dungeon_data = generate_dungeon(floor=i, rng=rng)
        file_name = os.path.join(args.out, f"dungeon_{i}.txt")
        with open(file_name, "w", newline="\n") as f:
            for row in dungeon_data:
                f.write(row + "\n")
        print(f"Generated {file_name} (floor {i})")
    print(f"Generated {args.floors} dungeon(s) in {args.out}")


if __name__ == "__main__":
    main()
