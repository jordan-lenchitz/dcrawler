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

### `$IO` (Input/Output Device)
*   **Purpose:** Intrinsic special variable identifying the current I/O device.
*   **MUMPS/GT.M Notes:** Can be used for logging or complex device handling.
*   **`dcrawl` Usage:** Displayed in the status bar in `DCRAWL.m` for informational purposes.
    ```mumps
    W "  $IO ",$IO
    ```

### `$TEST` (Result of Last Conditional Command)
*   **Purpose:** Intrinsic special variable indicating the success or failure of the last `IF`, `FOR`, or `XECUTE` command. `1` (true) if successful, `0` (false) otherwise.
*   **MUMPS/GT.M Notes:** Useful for robust error checking or conditional logic.
*   **`dcrawl` Usage:** Captured after a conditional check in `MLOOP` and displayed in the status bar in `DCRAWL.m`.
    ```mumps
    S LASTTEST=$TEST ; Capture $TEST after the conditional
    ; ...
    W "  $TEST ",LASTTEST
    ```

### `$KEY` (Keyboard Input)
*   **Purpose:** Intrinsic special variable that returns the last character typed from the keyboard (when in character-by-character input mode). It is cleared after being read.
*   **MUMPS/GT.M Notes:** Essential for responsive, character-by-character input handling without needing to press enter.
*   **`dcrawl` Usage:** Used in the new `INSPECT` routine to read single key presses for movement within inspection mode. Also, `R *CH` implicitly uses `$KEY` to get raw character input.
    ```mumps
    INSLOOP ;
     D MOVECUR^DCTERM(IX,IY)
     R *CH ; Reads a single character, often internally using $KEY
     I CH=27 G INSQ ; Escape to quit
    ```

### `$RANDOM` (Random Number Generator)
*   **Purpose:** Intrinsic function `$RANDOM(N)` returns a pseudo-random integer between 0 and `N-1`.
*   **MUMPS/GT.M Notes:** Useful for introducing randomness into gameplay.
*   **`dcrawl` Usage:** Used in `DCENT.m` within the `TICK` routine to generate random directions for enemy movement.
    ```mumps
    S DIR=$R(4) ; 0:up, 1:down, 2:left, 3:right
    ```

### `$HOROLOG` (Date and Time)
*   **Purpose:** Intrinsic special variable returning the current date and time in a specific format (e.g., `date,time` where `date` is days since Dec 31, 1840, and `time` is seconds since midnight).
*   **MUMPS/GT.M Notes:** Useful for in-game clocks or timestamps.
*   **`dcrawl` Usage:** Displayed in the status bar in `DCRAWL.m` for informational purposes.
    ```mumps
    W "  $H ",$HOROLOG
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
