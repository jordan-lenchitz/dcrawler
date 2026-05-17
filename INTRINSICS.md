# INTRINSICS.md

This document details the MUMPS intrinsic special variables and functions used or planned for use in the `dcrawl` dungeon crawler. It aims to clarify their purpose, standard behavior, and specific usage within this project, especially in the context of GT.M / YottaDB.

## Used Intrinsics

### `$X` and `$Y` (Cursor Position)
*   **Purpose:** `$X` and `$Y` are intrinsic special variables that represent the horizontal and vertical cursor positions, respectively, on the current device. In `dcrawl`, they are fundamental to player movement and map rendering.
*   **MUMPS/GT.M Notes:** These variables directly reflect and control the cursor's coordinates. Modifying `$X` or `$Y` immediately moves the cursor.
*   **`dcrawl` Usage:**
    *   **Player Position:** Unconventionally, `$X` and `$Y` are the *sole source of truth* for the player's position. The game doesn't store player coordinates in local variables or globals (except for `PX`, `PY` which are locals read from `$X`, `$Y` at the start of each turn).
    *   **Movement Invariant:** The main game loop in `DCRAWL.m` maintains an invariant: at the top of the `MLOOP`, `$X` and `$Y` always point at the player's current location.
    *   **Cursor Control:** `DCTERM.m`'s `MOVECUR` routine uses ANSI escape codes to explicitly move the cursor, then updates `$X` and `$Y` to match the new position, ensuring consistency.

### `$P` (Ambiguous: `$PIECE` Function and `$PRINCIPAL` Device)
The `$P` abbreviation in MUMPS can refer to two distinct intrinsics, its meaning is entirely context-dependent.

#### `$PIECE` (Function)
*   **Purpose:** `$PIECE(string, delimiter, [from_piece], [to_piece])` is an intrinsic function used to extract substrings (or "pieces") from a `string` based on a `delimiter`.
*   **MUMPS/GT.M Notes:** A widely used string manipulation function.
*   **`dcrawl` Usage:** Used in `DCTYPE.m` within the `FIELD` function to parse caret-separated fields from type definitions stored in `^TYPE`.
    ```mumps
    Q $P($G(^TYPE(KIND,GLYPH)),"^",N)
    ```

#### `$PRINCIPAL` (Special Variable)
*   **Purpose:** `$PRINCIPAL` is an intrinsic special variable representing the primary I/O device of the current process (typically the terminal).
*   **MUMPS/GT.M Notes:** Used with the `USE` command to direct I/O to or from the primary device.
*   **`dcrawl` Usage:** Used in `DCTERM.m` within the `INIT` and `END` routines to configure the terminal's raw mode and restore it. The code uses `U $P` where `$P` is implicitly `$PRINCIPAL`.
    ```mumps
    INIT ; raw mode on $PRINCIPAL
     U $P:(NOECHO:TERMINATOR="":WIDTH=80:LENGTH=24)
    ```

### `$J` (Job Number)
*   **Purpose:** `$J` is an intrinsic special variable holding the current process's job number (or process ID).
*   **MUMPS/GT.M Notes:** Useful for identifying and tracking processes.
*   **`dcrawl` Usage:** Displayed in the status bar in `DCRAWL.m` for debugging or informational purposes.
    ```mumps
    W "  $J ",$J
    ```

### `$ZEOF` (End of File)
*   **Purpose:** `$ZEOF` is a GT.M specific intrinsic special variable that indicates whether the end of a file has been reached during a read operation. It is `1` (true) if EOF, `0` (false) otherwise.
*   **MUMPS/GT.M Notes:** This intrinsic is specific to GT.M (and YottaDB, its successor). Standard MUMPS implementations might use other mechanisms for EOF checking.
*   **`dcrawl` Usage:** Used in `DCMAP.m` during the `LOAD` routine to read the `dungeon.txt` file line by line until the end is reached.
    ```mumps
    F  D  Q:$ZEOF
     . R L:5
     . I $ZEOF Q
    ```

### `$D` (Ambiguous: `$DATA` Function and `$DEVICE` Special Variable)
The `$D` abbreviation in MUMPS can refer to two distinct intrinsics, its meaning is entirely context-dependent.

#### `$DATA` (Function)
*   **Purpose:** `$DATA(variable)` is an intrinsic function that returns an integer indicating whether a `variable` exists and if it has descendants.
    *   `0`: Variable does not exist.
    *   `1`: Variable exists, has no descendants.
    *   `10`: Variable does not exist, but has descendants.
    *   `11`: Variable exists and has descendants.
*   **MUMPS/GT.M Notes:** Essential for checking the existence and structure of variables (local or global arrays).
*   **`dcrawl` Usage:** Primarily used to check for the existence of global arrays like `^G("ent",Y,X)` (entities) or `^G("inv",I)` (inventory items), and to check if player start coordinates `SX`, `SY` were found.
    ```mumps
    I '$D(^G("ent",Y,X)) Q 0  ; Check if an entity exists at X,Y
    I '$D(SX) W "no @ in dungeon.txt" Q ; Check if starting position was found
    ```

#### `$DEVICE` (Special Variable)
*   **Purpose:** `$DEVICE` is an intrinsic special variable that indicates the status of the current device. It can contain device-specific information, often related to errors or conditions.
*   **MUMPS/GT.M Notes:** Its content is highly device-dependent.
*   **`dcrawl` Usage:** This intrinsic was *not found* to be directly used in the `dcrawl` codebase. Its inclusion here is based on its common abbreviation `$D`.

### `$ZUT` (GT.M Terminal Utility)
*   **Purpose:** `$ZUT` is a GT.M specific intrinsic special variable, a general-purpose terminal utility intrinsic. Its behavior depends on the value assigned to it or the arguments passed. It can be used for various terminal control functions.
*   **MUMPS/GT.M Notes:** This is a GT.M extension, not part of standard MUMPS. It's often used for non-standard terminal interactions.
*   **`dcrawl` Usage:** Used in `DCRAWL.m` within the `WIN` and `DEATH` routines, likely to pause execution or clear input buffers before exiting.
    ```mumps
    W "you reached the stairs. press any key. $ZUT=",$ZUT
    R *CH:30
    ```

## Planned Intrinsics (Mentioned in README, Not Currently in Code)

The `README.md` mentions the planning of an `INTRINSICS.md` companion document that would include the following intrinsics, but they are not currently found in the MUMPS source code files of this project. Their potential future use would likely involve:

### `$IO` (Input/Output Device)
*   **Purpose:** Intrinsic special variable identifying the current I/O device.
*   **Potential `dcrawl` Usage:** Could be used for more complex device handling, logging, or alternative input/output streams.

### `$TEST` (Result of Last Conditional Command)
*   **Purpose:** Intrinsic special variable indicating the success or failure of the last `IF`, `FOR`, or `XECUTE` command. `1` (true) if successful, `0` (false) otherwise.
*   **Potential `dcrawl` Usage:** Could be used for more robust error checking or conditional logic based on command outcomes.

### `$KEY` (Keyboard Input)
*   **Purpose:** Intrinsic special variable that returns the last character typed from the keyboard (when in character-by-character input mode).
*   **Potential `dcrawl` Usage:** Could replace or augment the `R *CH` command for more fine-grained keyboard input handling, potentially allowing for more complex control schemes.

### `$RANDOM` (Random Number Generator)
*   **Purpose:** Intrinsic function `$RANDOM(N)` returns a pseudo-random integer between 0 and `N-1`.
*   **Potential `dcrawl` Usage:** Essential for introducing randomness, such as random enemy movement, dungeon generation, or item drops.

### `$HOROLOG` (Date and Time)
*   **Purpose:** Intrinsic special variable returning the current date and time in a specific format (e.g., `date,time` where `date` is days since Dec 31, 1840, and `time` is seconds since midnight).
*   **Potential `dcrawl` Usage:** Could be used for in-game clocks, timestamps for logs, or to implement time-based events.
