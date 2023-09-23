; ActRaiser Practice ROM
; Osteoclave
; 2023-08-16 - Migration from xkas v14 to asar 1.81
; 2020-10-03 - Original version, assembled using xkas v14
;
; Assemble with "--fix-checksum=off" to match the original xkas output.

asar 1.81
math pri on
math round off
check title "ACTRAISER-USA        "

arch 65816
lorom
bank noassume



; SNES registers
incsrc registers.asm

; Vanilla constants
!DMA_CHANNEL_4 = $10
!JOYPAD_B      = $8000
!JOYPAD_SELECT = $2000
!JOYPAD_START  = $1000
!JOYPAD_UP     = $0800
!JOYPAD_DOWN   = $0400
!JOYPAD_LEFT   = $0200
!JOYPAD_RIGHT  = $0100

; Vanilla variables
!currentMap      = $18
!changeMap       = $1A
!currentHealth   = $1D
!maximumHealth   = $1E
!playerX         = $80
!playerY         = $82
!frameCounter    = $88
!scheduledHDMA   = $92
!vramWriteSource = $D0
!vramWriteDest   = $D3
!vramWriteSize   = $D5
!swordUpgrade    = $E4
!discardInput    = $F4
!ignoreInput     = $F6
!equippedMagic   = $02AC
!rng             = $02D1
!respawnX        = $032E
!respawnY        = $0330
!pauseStatus     = $0332
!difficulty      = $0349
!tilemapBG3      = $7FB000

; Vanilla labels
ShortRandom   = $0084C0
CountdownTick = $02BC82
PrintText     = $02BF60
UpdateHUD     = $02C206
MagicIcons    = $06A400

; New variables
; In vanilla, 7E024C-0281 contains the "offering" inventories for each town.
; The practice ROM never enters town-building mode, so we can repurpose this
; memory safely.
!menuCursor     = $024C
!heldButton     = $024E
!heldCounter    = $0250
!countdownOff   = $0252
!memoryViewerOn = $0254
; Cached values for the memory viewer
!cacheXH = $0256
!cacheXL = $0257
!cacheYH = $0258
!cacheYL = $0259
!cacheR  = $025A
!cacheFH = $025B
!cacheIH = $025C
!cacheIL = $025D
; Joypad input bits, sorted for the input viewer
!inputUDLR = $025E
!inputEL   = $0260
!inputTR   = $0262
!inputBYAX = $0264
; More new variables
!magicIcon    = $0266
!onExitAction = $0268
!currentRoom  = $026A
!selectedRoom = $026C
; "On room load" actions
!autoHeal  = $026E
!autoSword = $026F
!autoEasy  = $0270

; New constants
; Number of items in the various selectable menus.
!MENU_LENGTH    = 11
!MAGIC_LENGTH   = 5
!ON_EXIT_LENGTH = 3
!ROOMS_LENGTH   = 55
; Number of eligible destinations when the on-exit action is "RANDOM".
; This is less than the total number of rooms because we don't want
; checkpoints or at-boss spawn points to be eligible destinations.
!DESTINATIONS_LENGTH = 48
; Repeat delay and repeat rate for held buttons.
!REPEAT_DELAY = 15
!REPEAT_RATE  = 6



; Windowing registers: Don't invert the windows.
org   $02C6CB
lda   #$22
; Windowing registers: Disable window 1 on BG3.
org   $02C6D0
stz   !W34SEL
; Windowing registers: Set window 1's range to zero.
org   $02C6D6
lda   #$FF
org   $02C6DB
lda   #$00

; Look for map metadata at 0xF8000 instead of 0x28000.
org   $02BE28
lda   #$1F

; Insert new text for the title screen.
org   $02A9A7
NewTitleScreenText:
    db    "> PRACTICE", $0D
    db    $0D
    db    $0D
    db    "  v0.4, 2020-10-26", $0D
    db    "     by Osteoclave"
    db    $00

; Force the title screen menu to only have one option. (This normally
; happens when there's no save data, and only "START" is displayed.)
org   $02A70D
nop
nop

; Print the new text instead of "START" for that one menu option.
org   $02A711
lda   #$110B
ldy.w #NewTitleScreenText

; Always enter Professional Mode from the title screen menu.
org   $008040
nop
nop

; Always show 99 lives remaining at the top of the screen.
org   $02C28E
lda   #$39
org   $02C29E
lda   #$39

; Upon death, don't reduce the number of lives remaining.
org   $0082B1
nop
nop

; Take control of the countdown timer.
org   $0080A0
jsl   NewCountdownTick
org   $0080DB
jsl   NewCountdownTick

; If you have no magic equipped, display the empty-box icon.
org   $02BCDB
lda   #$0005

; Allow magic to be used at will: no MP required, no MP cost.
org   $009E03
bra   $03
org   $009E0A
nop
nop

; Always show ten MP scrolls at the top of the screen.
org   $02C2DC
nop
nop

; Prevent the Magical Stardust spell from doing double damage.
; During object creation, if:
; - The game is in Professional Mode
; - Certain flags on the new object are clear
; - The new object's attack power is equal to one
; Then the new object's attack power is increased to two.
; The other spells are not affected by this boost: Magical Fire and Magical
; Aura both have one of the relevant flags set, and Magical Light's attack
; power is already 2, so it's not eligible.
; Anyway. Let's add some code to keep the attack power of meteors at one.
org   $009F7B
lda   #$FF40
org   $00FF40
lda   #$0001
sta   $002A,x
lda   #$A0E8
sta   $0012,x
jmp   $A0E8

; Merge the 02/BB4C and 02/BC27 functions.
; "JSL $02BB4C" is always followed by "JSL $02BC27", and 02/BB4C is located
; immediately before 02/BC27 in the ROM. If we replace the RTL at the end of
; 02/BB4C with a NOP, we can execute both functions with just "JSL $02BB4C".
; "JSL $02BC27" can then be replaced with a JSL to new code.
; (Specifically, new code to update the memory viewer.)
org   $02BC26
nop
org   $008098
jsl   UpdateMemoryViewer
org   $0080D3
jsl   UpdateMemoryViewer
; This JSL is executed during room transitions (both fade-out and fade-in).
; BG3 gets cleared during room transitions, and "UpdateMemoryViewer" only
; draws the values that have changed (intentional time-saving behaviour).
; So calling "UpdateMemoryViewer" here could result in a partially-drawn
; memory viewer when the new room loads.
; To avoid that, we use "ForceUpdateMemoryViewer" instead.
org   $008304
jsl   ForceUpdateMemoryViewer

; When updating the BG3 tilemap in VRAM, include the memory viewer.
org   $02AF13
jmp   $C840
org   $02C840
; The accumulator is 8-bit and holds the value of $F1 here.
beq   +
; If $F1 is nonzero, we're copying the full BG3 tilemap to VRAM. This will
; copy the memory viewer as well, so we don't need to do anything.
jmp   $AF16
+
ldx   !memoryViewerOn
beq   +
ldx   #$5B41
stx   !VMADDL
ldx   #$B682
stx   !A1T0L
ldx   #$003C
stx   !DAS0L
lda   #$01
sta   !MDMAEN
+
rts

; Skip the "descending ball of light brings statue to life" animation.
org   $02AB0D
stz   $00FC

; Replace the existing Start-button pause handler.
org   $008066
jsl   NewPauseHandler

; Perform the "on room load" actions when loading a room. These actions
; happen on all room loads: manual loading, exiting a room, death, etc.
org   $00826C
jsl   OnRoomLoad

; Always use the respawn coordinates if they're set, not just after a death.
org   $009380
nop
nop

; In the event of player death, respawn on the same map.
org   $02BD61
nop
nop
lda   !currentMap+1

; On room exit, load the next room according to the current on-exit action.
; 102
org   $00B030
jsl   LoadNextRoom
rts
; 103
org   $00B03B
jsl   LoadNextRoom
rts
; 202
org   $00B92B
jsl   LoadNextRoom
rts
; 203
org   $00B939
jsl   LoadNextRoom
rts
; 204
org   $00B947
jsl   LoadNextRoom
rts
; 205
org   $00B955
jsl   LoadNextRoom
rts
; 206
org   $00B963
jsl   LoadNextRoom
rts
; 207
org   $00B971
jsl   LoadNextRoom
rts
; 301
org   $00C15E
jsl   LoadNextRoom
rts
; 303
org   $00C16C
jsl   LoadNextRoom
rts
; 304
org   $00C186
jsl   LoadNextRoom
rts
; 305
org   $00C19C
jsl   LoadNextRoom
rts
; 401
org   $00CDEB
jsl   LoadNextRoom
rts
; 402
org   $00CDF9
jsl   LoadNextRoom
rts
; 404
org   $00CE0F
jsl   LoadNextRoom
rts
; 405
org   $00CE1D
jsl   LoadNextRoom
rts
; 406
org   $00CE33
jsl   LoadNextRoom
rts
; 501
org   $00E6C6
jsl   LoadNextRoom
rts
; 502
org   $00E6D4
jsl   LoadNextRoom
rts
; 504
org   $00E6EA
jsl   LoadNextRoom
rts
; 505 = The room-with-two-exits in the Marahna temple (a special case)
org   $00E6F8
lda   !playerX
cmp   #$0180
bcc   +
cmp   #$02E0
bcs   +
rts
+
jsl   LoadNextRoom
rts
; 506 and 507
org   $00E71C
jsl   LoadNextRoom
rts
; 601
org   $00E766
jsl   LoadNextRoom
rts
; 602
org   $00E774
jsl   LoadNextRoom
rts
; 603
org   $00E78A
jsl   LoadNextRoom
rts
; 605
org   $00E7A0
jsl   LoadNextRoom
rts
; 606
org   $00E7AB
jsl   LoadNextRoom
rts
; 607
org   $00E7B6
jsl   LoadNextRoom
rts

; Upon completing an Act, don't increment the "Acts completed" counter. Load
; the next room according to the current on-exit action.
org   $008788
jsl   LoadNextRoom
bra   $0A

; When completing an Act on normal difficulty, don't do the score count-up.
org   $00A205
nop
nop

; When completing an Act on normal difficulty, don't return to sim mode.
org   $00A2CF
nop
nop

; Upon defeating a boss in the boss rush, don't increment the "bosses
; defeated in the boss rush" counter. Load the next room according to the
; current on-exit action.
org   $00FEEC
jsl   LoadNextRoom
bra   $08
org   $00FF00
bra   $05

; Prevent animated tiles from glitching.
org   $0289E2
db    $08
org   $028A6E
db    $02
org   $028AA6
db    $02
org   $028B32
db    $08
org   $028B6A
db    $04
org   $028B86
db    $04
org   $028BA2
db    $04
org   $028C2E
db    $08
org   $028C4A
db    $08
org   $028C9E
db    $08
org   $028CBA
db    $08
org   $028CF2
db    $04
org   $028D0E
db    $04
org   $028D2A
db    $04
org   $028D9A
db    $08
org   $028DB6
db    $08
org   $028DEE
db    $08
org   $028E0A
db    $08

; The random-number generation function lives in bank 00 and ends with a
; short return (RTS). We want to generate random numbers from outside that
; bank, so let's create a helper function in bank 00 that ends with a long
; return (RTL).
org   $00FF60
LongRandom:
    jsr   ShortRandom
    rtl

; Use the modified font.
; - Erased the leftover Japanese characters from tiles 0x80-FF
; - 0x80-8F: Copied the 0-9/A-F characters to simplify the memory viewer
; - 0x90-B3: New graphics tiles for the input viewer
org    $17ECFB
incbin actraiser_font_modified_compressed.bin
warnpc $17F7A2



; Updated map metadata: each map now loads all of its required assets.
org    $1F8000
incsrc map_metadata_usa.asm



NewCountdownTick:
    php
    rep   #$20
    lda   !countdownOff
    bne   +
    sep   #$20
    jsl   CountdownTick
    +
    plp
    rtl



UpdateMemoryViewer:
    php
    rep   #$20
    lda   !memoryViewerOn
    beq   +
    jsr   DrawMemoryViewer
    +
    plp
    rtl



ForceUpdateMemoryViewer:
    php
    rep   #$20
    lda   !memoryViewerOn
    beq   +
    jsr   InvalidateCache
    jsr   DrawMemoryViewer
    +
    plp
    rtl



InvalidateCache:
    php
    sep   #$20
    pha
    ; Player's X coordinate, high byte
    lda   !playerX+1
    eor   #$FF
    sta   !cacheXH
    ; Player's X coordinate, low byte
    lda   !playerX
    eor   #$FF
    sta   !cacheXL
    ; Player's Y coordinate, high byte
    lda   !playerY+1
    eor   #$FF
    sta   !cacheYH
    ; Player's Y coordinate, low byte
    lda   !playerY
    eor   #$FF
    sta   !cacheYL
    ; RNG state
    lda   !rng
    eor   #$FF
    sta   !cacheR
    ; Frame counter, high byte
    lda   !frameCounter+1
    eor   #$FF
    sta   !cacheFH
    ; Frame counter, low byte = Not cached (changes every frame)
    ; Joypad input, high byte
    lda   !JOY1H
    eor   #$FF
    sta   !cacheIH
    ; Joypad input, low byte
    lda   !JOY1L
    eor   #$FF
    sta   !cacheIL
    pla
    plp
    rts



DrawMemoryViewer:
    php
    rep   #$20
    pha
    ; Draw the labels if they're absent (e.g. erased by room transition)
    lda   #$2458
    cmp   !tilemapBG3+(26<<6)+(1<<1)
    beq   +
    sta   !tilemapBG3+(26<<6)+(1<<1)
    lda   #$2459
    sta   !tilemapBG3+(26<<6)+(8<<1)
    lda   #$2452
    sta   !tilemapBG3+(26<<6)+(20<<1)
    lda   #$2446
    sta   !tilemapBG3+(26<<6)+(25<<1)
    +
    sep   #$20
    ; Player's X coordinate, high byte
    ldx.w #3<<1
    lda   !playerX+1
    cmp   !cacheXH
    beq   +
    sta   !cacheXH
    jsr   DrawByte
    +
    ; Player's X coordinate, low byte
    ldx.w #5<<1
    lda   !playerX
    cmp   !cacheXL
    beq   +
    sta   !cacheXL
    jsr   DrawByte
    +
    ; Player's Y coordinate, high byte
    ldx.w #10<<1
    lda   !playerY+1
    cmp   !cacheYH
    beq   +
    sta   !cacheYH
    jsr   DrawByte
    +
    ; Player's Y coordinate, low byte
    ldx.w #12<<1
    lda   !playerY
    cmp   !cacheYL
    beq   +
    sta   !cacheYL
    jsr   DrawByte
    +
    ; RNG state
    ldx.w #22<<1
    lda   !rng
    cmp   !cacheR
    beq   +
    sta   !cacheR
    jsr   DrawByte
    +
    ; Frame counter, high byte
    ldx.w #27<<1
    lda   !frameCounter+1
    cmp   !cacheFH
    beq   +
    sta   !cacheFH
    jsr   DrawByte
    +
    ; Frame counter, low byte
    ; This is not cached because it's expected to change every frame
    ldx.w #29<<1
    lda   !frameCounter
    jsr   DrawByte
    ; Has the joypad input changed?
    lda   !JOY1H
    cmp   !cacheIH
    bne   .InputChanged
    lda   !JOY1L
    cmp   !cacheIL
    beq   .InputUnchanged
.InputChanged:
    stz   !inputBYAX
    stz   !inputEL
    stz   !inputTR
    ; Joypad input, high byte
    lda   !JOY1H
    sta   !cacheIH
    and   #$0F
    sta   !inputUDLR
    lda   !JOY1H
    asl
    rol   !inputBYAX
    asl
    rol   !inputBYAX
    asl
    rol   !inputEL
    asl
    rol   !inputTR
    ; Joypad input, low byte
    lda   !JOY1L
    sta   !cacheIL
    asl
    rol   !inputBYAX
    asl
    rol   !inputBYAX
    asl
    rol   !inputEL
    asl
    rol   !inputTR
    ; Draw the input display
    rep   #$20
    lda   !inputUDLR
    ora   #$2890
    sta   !tilemapBG3+(26<<6)+(15<<1)
    lda   !inputEL
    ora   #$28B0
    sta   !tilemapBG3+(26<<6)+(16<<1)
    lda   !inputTR
    ora   #$68B0
    sta   !tilemapBG3+(26<<6)+(17<<1)
    lda   !inputBYAX
    ora   #$28A0
    sta   !tilemapBG3+(26<<6)+(18<<1)
.InputUnchanged:
    rep   #$20
    pla
    plp
    rts



DrawByte:
    ; First digit
    pha
    lsr
    lsr
    lsr
    lsr
    ora   #$80
    sta   !tilemapBG3+(26<<6),x
    inx
    inx
    pla
    ; Second digit
    and   #$0F
    ora   #$80
    sta   !tilemapBG3+(26<<6),x
    inx
    inx
    rts



EraseMemoryViewer:
    php
    sep   #$20
    pha
    lda   #$00
    sta   !tilemapBG3+(26<<6)+(1<<1)
    sta   !tilemapBG3+(26<<6)+(3<<1)
    sta   !tilemapBG3+(26<<6)+(4<<1)
    sta   !tilemapBG3+(26<<6)+(5<<1)
    sta   !tilemapBG3+(26<<6)+(6<<1)
    sta   !tilemapBG3+(26<<6)+(8<<1)
    sta   !tilemapBG3+(26<<6)+(10<<1)
    sta   !tilemapBG3+(26<<6)+(11<<1)
    sta   !tilemapBG3+(26<<6)+(12<<1)
    sta   !tilemapBG3+(26<<6)+(13<<1)
    sta   !tilemapBG3+(26<<6)+(15<<1)
    sta   !tilemapBG3+(26<<6)+(16<<1)
    sta   !tilemapBG3+(26<<6)+(17<<1)
    sta   !tilemapBG3+(26<<6)+(18<<1)
    sta   !tilemapBG3+(26<<6)+(20<<1)
    sta   !tilemapBG3+(26<<6)+(22<<1)
    sta   !tilemapBG3+(26<<6)+(23<<1)
    sta   !tilemapBG3+(26<<6)+(25<<1)
    sta   !tilemapBG3+(26<<6)+(27<<1)
    sta   !tilemapBG3+(26<<6)+(28<<1)
    sta   !tilemapBG3+(26<<6)+(29<<1)
    sta   !tilemapBG3+(26<<6)+(30<<1)
    pla
    plp
    rts



NewPauseHandler:
    lda   !pauseStatus
    bmi   .Done
    bne   .Paused
    lda   !JOY1H
    bit.b #!JOYPAD_START>>8
    beq   .Done
    ; Open the practice menu
    jsr   PracticeMenu
    rtl

.Paused:
    ; Stay in the "paused" state until the Start button has been released
    lda   !JOY1H
    bit.b #!JOYPAD_START>>8
    bne   .Done
    stz   !pauseStatus

.Done:
    rtl



PracticeMenu:
    ; Switch to bank 00
    phb
    lda   #$00
    pha
    plb

    ; Enter the "paused" state
    inc   !pauseStatus

    ; Pause the music
    lda   #$F2
    sta   !APUIO0

    ; Draw the window
    lda   #$01
    sta   !DMAP4
    lda   #$26
    sta   !BBAD4
    ldx.w #WindowData
    stx   !A1T4L
    lda.b #WindowData>>16
    sta   !A1B4
    lda   #!DMA_CHANNEL_4
    tsb   !scheduledHDMA

    ; Set initial menu variables
    rep   #$20
    stz   !menuCursor
    stz   !heldButton
    stz   !heldCounter
    lda   !equippedMagic
    and   #$00FF
    sta   !magicIcon
    lda   !currentRoom
    sta   !selectedRoom

    ; Draw the menu
    jsr   DrawMenu

    ; Wait for the Start button to be released
    lda   #!JOYPAD_START
    jsr   WaitForKeyup

.Loop:
    ; Practice menu behaviour: Select button
    lda   #!JOYPAD_SELECT
    bit   !JOY1L
    beq   +
    pha
    sep   #$20
    lda   #!DMA_CHANNEL_4
    trb   !scheduledHDMA
    rep   #$20
    jsr   EraseMenu
    pla
    jsr   WaitForKeyup
    sep   #$20
    lda   #!DMA_CHANNEL_4
    tsb   !scheduledHDMA
    rep   #$20
    jsr   DrawMenu
    +

    ; Practice menu behaviour: Start button
    lda   #!JOYPAD_START
    bit   !JOY1L
    beq   +
    jmp   .Break
    +

    ; Practice menu behaviour: Up button
    lda   #!JOYPAD_UP
    jsr   CheckButton
    bcc   ++
    lda   !menuCursor
    dec
    bpl   +
    lda.w #!MENU_LENGTH-1
    +
    sta   !menuCursor
    jmp   .RedrawMenu
    ++

    ; Practice menu behaviour: Down button
    lda   #!JOYPAD_DOWN
    jsr   CheckButton
    bcc   ++
    lda   !menuCursor
    inc
    cmp.w #!MENU_LENGTH
    bcc   +
    lda.w #0
    +
    sta   !menuCursor
    jmp   .RedrawMenu
    ++

    ; Menu option behaviour
    lda   !menuCursor

.ResumeGame:
    cmp.w #0
    bne   .RestoreHealth
    lda   #!JOYPAD_B
    bit   !JOY1L
    beq   +
    ; Prevent this B-press from making the player jump
    trb   !ignoreInput
    jmp   .Break
    +
    jmp   .NextFrame

.RestoreHealth:
    cmp.w #1
    bne   .ToggleCountdown
    lda   #!JOYPAD_B
    bit   !JOY1L
    beq   +
    pha
    sep   #$20
    lda   !maximumHealth
    sta   !currentHealth
    rep   #$20
    jsl   UpdateHUD
    pla
    jsr   WaitForKeyup
    +
    jmp   .NextFrame

.ToggleCountdown:
    cmp.w #2
    bne   .ToggleMemoryViewer
    lda   #!JOYPAD_B
    jsr   CheckButton
    bcc   ..NoPress
    lda   !countdownOff
    bne   ..Resume
..Pause:
    lda   #$0001
    sta   !countdownOff
    bra   ..Toggled
..Resume:
    stz   !countdownOff
..Toggled:
    jmp   .RedrawMenu
..NoPress:
    jmp   .NextFrame

.ToggleMemoryViewer:
    cmp.w #3
    bne   .MagicSelector
    lda   #!JOYPAD_B
    jsr   CheckButton
    bcc   ..NoPress
    lda   !memoryViewerOn
    bne   ..TurnOff
..TurnOn:
    lda   #$0001
    sta   !memoryViewerOn
    jsr   InvalidateCache
    jsr   DrawMemoryViewer
    bra   ..Toggled
..TurnOff:
    stz   !memoryViewerOn
    jsr   EraseMemoryViewer
..Toggled:
    jmp   .RedrawMenu
..NoPress:
    jmp   .NextFrame

.MagicSelector:
    cmp.w #4
    bne   .ToggleAutoHeal

    ; Magic selector behaviour: Left button
    lda   #!JOYPAD_LEFT
    jsr   CheckButton
    bcc   ++
    sep   #$20
    lda   !equippedMagic
    dec
    bpl   +
    lda.b #!MAGIC_LENGTH-1
    +
    sta   !equippedMagic
    rep   #$20
    jmp   .RedrawMenu
    ++

    ; Magic selector behaviour: Right button
    lda   #!JOYPAD_RIGHT
    jsr   CheckButton
    bcc   ++
    sep   #$20
    lda   !equippedMagic
    inc
    cmp.b #!MAGIC_LENGTH
    bcc   +
    lda.b #0
    +
    sta   !equippedMagic
    rep   #$20
    jmp   .RedrawMenu
    ++

    jmp   .NextFrame

.ToggleAutoHeal:
    cmp.w #5
    bne   .ToggleAutoSword
    lda   #!JOYPAD_B
    jsr   CheckButton
    bcc   ..NoPress
    sep   #$20
    lda   !autoHeal
    bne   ..TurnOff
..TurnOn:
    lda   #$01
    sta   !autoHeal
    bra   ..Toggled
..TurnOff:
    stz   !autoHeal
..Toggled:
    rep   #$20
    jmp   .RedrawMenu
..NoPress:
    jmp   .NextFrame

.ToggleAutoSword:
    cmp.w #6
    bne   .ToggleAutoEasy
    lda   #!JOYPAD_B
    jsr   CheckButton
    bcc   ..NoPress
    sep   #$20
    lda   !autoSword
    bne   ..TurnOff
..TurnOn:
    lda   #$01
    sta   !autoSword
    bra   ..Toggled
..TurnOff:
    stz   !autoSword
..Toggled:
    rep   #$20
    jmp   .RedrawMenu
..NoPress:
    jmp   .NextFrame

.ToggleAutoEasy:
    cmp.w #7
    bne   .OnExitSelector
    lda   #!JOYPAD_B
    jsr   CheckButton
    bcc   ..NoPress
    sep   #$20
    lda   !autoEasy
    bne   ..TurnOff
..TurnOn:
    lda   #$01
    sta   !autoEasy
    bra   ..Toggled
..TurnOff:
    stz   !autoEasy
..Toggled:
    rep   #$20
    jmp   .RedrawMenu
..NoPress:
    jmp   .NextFrame

.OnExitSelector:
    cmp.w #8
    bne   .RoomSelector

    ; On-exit selector behaviour: Left button
    lda   #!JOYPAD_LEFT
    jsr   CheckButton
    bcc   ++
    lda   !onExitAction
    dec
    bpl   +
    lda.w #!ON_EXIT_LENGTH-1
    +
    sta   !onExitAction
    jmp   .RedrawMenu
    ++

    ; On-exit selector behaviour: Right button
    lda   #!JOYPAD_RIGHT
    jsr   CheckButton
    bcc   ++
    lda   !onExitAction
    inc
    cmp.w #!ON_EXIT_LENGTH
    bcc   +
    lda.w #0
    +
    sta   !onExitAction
    jmp   .RedrawMenu
    ++

    jmp   .NextFrame

.RoomSelector:
    cmp.w #9
    bne   .LoadSelectedRoom

    ; Room selector behaviour: Left button
    lda   #!JOYPAD_LEFT
    jsr   CheckButton
    bcc   ++
    lda   !selectedRoom
    dec
    bpl   +
    lda.w #!ROOMS_LENGTH-1
    +
    sta   !selectedRoom
    bra   .RedrawMenu
    ++

    ; Room selector behaviour: Right button
    lda   #!JOYPAD_RIGHT
    jsr   CheckButton
    bcc   ++
    lda   !selectedRoom
    inc
    cmp.w #!ROOMS_LENGTH
    bcc   +
    lda.w #0
    +
    sta   !selectedRoom
    bra   .RedrawMenu
    ++

    bra   .NextFrame

.LoadSelectedRoom:
    cmp.w #10
    bne   .NextFrame
    lda   #!JOYPAD_B
    bit   !JOY1L
    beq   +
    ; Prevent this B-press from making the player jump
    ; The room transition resets "ignoreInput" (i.e. no inputs ignored), so
    ; we can't use it like we did in ".ResumeGame" above. Instead, we use
    ; the more aggressive "discardInput".
    trb   !discardInput
    lda   !selectedRoom
    sta   !currentRoom
    asl
    tax
    lda   MapNumbers,x
    sta   !changeMap
    jmp   .Break
    +
    bra   .NextFrame

.RedrawMenu:
    jsr   EraseMenu
    jsr   DrawMenu
.NextFrame:
    dec   !frameCounter
    jsr   WaitForVBlank
    jmp   .Loop

.Break:
    ; Erase the menu
    jsr   EraseMenu

    ; Erase the window
    sep   #$20
    lda   #!DMA_CHANNEL_4
    trb   !scheduledHDMA

    ; Unpause the music
    lda   #$01
    sta   !APUIO0
    jsr   WaitForVBlank
    plb
    rts



CheckButton:
    pha
    bit   !JOY1L
    beq   .ButtonNotPressed
    cmp   !heldButton
    bne   .ButtonNewPress
    dec   !heldCounter
    bne   .ButtonInCooldown
    lda.w #!REPEAT_RATE
    sta   !heldCounter
    bra   .ButtonPressed
.ButtonNewPress:
    sta   !heldButton
    lda.w #!REPEAT_DELAY
    sta   !heldCounter
.ButtonPressed:
    pla
    sec
    rts
.ButtonNotPressed:
    cmp   !heldButton
    bne   +
    stz   !heldButton
    stz   !heldCounter
    +
.ButtonInCooldown:
    pla
    clc
    rts



DrawMenu:
    phb
    sep   #$20
    lda   #$1F
    pha
    plb
    rep   #$20

    ; Check if the magic icon needs to be updated.
    lda   !equippedMagic
    and   #$00FF
    cmp   !magicIcon
    beq   ++
    sta   !magicIcon
    cmp   #$0000
    bne   +
    ; If you have no magic equipped, display the empty-box icon.
    lda   #$0005
    +
    dec
    xba
    lsr
    clc
    adc.w #MagicIcons
    sta   !vramWriteSource
    sep   #$20
    lda.b #MagicIcons>>16
    sta   !vramWriteSource+2
    rep   #$20
    lda   #$2D40
    sta   !vramWriteDest
    lda   #$0080
    sta   !vramWriteSize
    ++

    ; Resume game
    ldy.w #TEXT_ResumeGame
    lda   #$0507
    jsl   PrintText

    ; Restore health
    ldy.w #TEXT_RestoreHealth
    lda   #$0607
    jsl   PrintText

    ; Toggle countdown
    ldy.w #TEXT_CountdownRunning
    lda   !countdownOff
    beq   +
    ldy.w #TEXT_CountdownPaused
    +
    lda   #$0707
    jsl   PrintText

    ; Toggle memory viewer
    ldy.w #TEXT_MemoryViewerOff
    lda   !memoryViewerOn
    beq   +
    ldy.w #TEXT_MemoryViewerOn
    +
    lda   #$0807
    jsl   PrintText

    ; Magic selector
    lda   !equippedMagic
    and   #$00FF
    asl
    tax
    lda   MagicDescriptions,x
    tay
    lda   #$0A09
    jsl   PrintText
    ; Arrows
    ldy.w #TEXT_LeftArrow
    lda   #$0A07
    jsl   PrintText
    ldy.w #TEXT_RightArrow
    lda   #$0A1A
    jsl   PrintText

    ; On room load
    ldy.w #TEXT_OnRoomLoad
    lda   #$0C07
    jsl   PrintText

    ; On room load: Auto-recovery
    ldy.w #TEXT_AutoHealOff
    lda   !autoHeal
    and   #$00FF
    beq   +
    ldy.w #TEXT_AutoHealOn
    +
    lda   #$0D07
    jsl   PrintText

    ; On room load: Sword upgrade
    ldy.w #TEXT_AutoSwordOff
    lda   !autoSword
    and   #$00FF
    beq   +
    ldy.w #TEXT_AutoSwordOn
    +
    lda   #$0E07
    jsl   PrintText

    ; On room load: Difficulty
    ldy.w #TEXT_AutoEasyOff
    lda   !autoEasy
    and   #$00FF
    beq   +
    ldy.w #TEXT_AutoEasyOn
    +
    lda   #$0F07
    jsl   PrintText

    ; On-exit selector
    lda   !onExitAction
    asl
    tax
    lda   OnExitDescriptions,x
    tay
    lda   #$1109
    jsl   PrintText
    ; Arrows
    ldy.w #TEXT_LeftArrow
    lda   #$1107
    jsl   PrintText
    ldy.w #TEXT_RightArrow
    lda   #$111A
    jsl   PrintText

    ; Room selector
    lda   !selectedRoom
    asl
    tax
    lda   RoomDescriptions,x
    tay
    lda   #$1309
    jsl   PrintText
    ; Arrows
    ldy.w #TEXT_LeftArrow
    lda   #$1407
    jsl   PrintText
    ldy.w #TEXT_RightArrow
    lda   #$141A
    jsl   PrintText

    ; Load selected room
    ldy.w #TEXT_LoadSelectedRoom
    lda   #$1707
    jsl   PrintText

    ; Cursor
    ldy.w #TEXT_Cursor
    lda   !menuCursor
    cmp.w #0
    bne   +
    lda   #$0505
    bra   .CursorPositioned
    +
    cmp.w #1
    bne   +
    lda   #$0605
    bra   .CursorPositioned
    +
    cmp.w #2
    bne   +
    lda   #$0705
    bra   .CursorPositioned
    +
    cmp.w #3
    bne   +
    lda   #$0805
    bra   .CursorPositioned
    +
    cmp.w #4
    bne   +
    lda   #$0A05
    bra   .CursorPositioned
    +
    cmp.w #5
    bne   +
    lda   #$0D05
    bra   .CursorPositioned
    +
    cmp.w #6
    bne   +
    lda   #$0E05
    bra   .CursorPositioned
    +
    cmp.w #7
    bne   +
    lda   #$0F05
    bra   .CursorPositioned
    +
    cmp.w #8
    bne   +
    lda   #$1105
    bra   .CursorPositioned
    +
    cmp.w #9
    bne   +
    lda   #$1405
    bra   .CursorPositioned
    +
    cmp.w #10
    bne   +
    lda   #$1705
.CursorPositioned:
    jsl   PrintText
    +

    plb
    rts



EraseMenu:
    phb
    sep   #$20
    lda   #$1F
    pha
    plb
    rep   #$20
    ldy.w #TEXT_EraseAll
    lda   #$0505
    jsl   PrintText
    plb
    rts



OnRoomLoad:
    ; Auto-recovery
    lda   !autoHeal
    beq   +
    lda   !maximumHealth
    sta   !currentHealth
    +
    ; Sword upgrade
    stz   !swordUpgrade
    lda   !autoSword
    beq   +
    lda   #$FF
    sta   !swordUpgrade
    +
    ; Difficulty
    stz   !difficulty
    lda   !autoEasy
    bne   +
    inc   !difficulty
    +
    ; Customized spawn points
    rep   #$20
    ; Clear the respawn coordinates.
    ; This intentionally overrides normal checkpoint behaviour: if you've
    ; chosen to play a room from the start, you will respawn at the start
    ; upon death, even if you passed a checkpoint before dying.
    ; To restore normal checkpoint behaviour, don't clear the respawn
    ; coordinates after a death (i.e. when $032C is nonzero).
    stz   !respawnX
    stz   !respawnY
    lda   !currentRoom
    ; 101 checkpoint
    cmp.w #1
    bne   +
    lda   #$09C0
    sta   !respawnX
    lda   #$0170
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 101 at boss
    cmp.w #2
    bne   +
    lda   #$0E50
    sta   !respawnX
    lda   #$02D0
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 201 checkpoint
    cmp.w #7
    bne   +
    lda   #$08A0
    sta   !respawnX
    lda   #$0190
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 201 at boss
    cmp.w #8
    bne   +
    lda   #$0E20
    sta   !respawnX
    lda   #$0170
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 302 at boss
    cmp.w #18
    bne   +
    lda   #$0920
    sta   !respawnX
    lda   #$0210
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 401 checkpoint
    cmp.w #24
    bne   +
    lda   #$0BD0
    sta   !respawnX
    lda   #$0350
    sta   !respawnY
    bra   .SpawnDone
    +
    ; 603 checkpoint
    cmp.w #42
    bne   +
    lda   #$0550
    sta   !respawnX
    lda   #$03F0
    sta   !respawnY
    +
.SpawnDone:
    sep   #$20
    ; Execute the instructions we overwrote in order to call this function
    lda   !changeMap
    sta   !currentMap+1
    rtl



LoadNextRoom:
    lda   !changeMap
    and   #$00FF
    beq   +
    ; If we're already in a room transition, we don't need to do anything.
    rtl
    +
    lda   !onExitAction
.Repeat:
    ; If the on-exit action is "REPEAT", repeat the current room.
    cmp.w #0
    bne   .Advance
    lda   !currentMap
    xba
    sta   !changeMap
    rtl
.Advance:
    ; If the on-exit action is "ADVANCE", advance to the next room.
    cmp.w #1
    bne   .Random
    phx
    lda   !currentRoom
    ; Handle the room-with-two-exits in the Marahna temple
    cmp.w #35
    bne   ..Normal
    lda   !playerX
    cmp   #$0180
    bcs   +
    ; Advancing through the left door
    lda.w #36
    bra   ..RoomFound
    +
    cmp   #$02E0
    bcc   +
    ; Advancing through the right door
    lda.w #37
    bra   ..RoomFound
    +
    ; Should-never-happen fallback: reload the room-with-two-exits
    lda.w #35
    bra   ..RoomFound
..Normal:
    asl
    tax
    lda   NextRooms,x
..RoomFound:
    sta   !currentRoom
    asl
    tax
    lda   MapNumbers,x
    sta   !changeMap
    plx
    rtl
.Random:
    ; If the on-exit action is "RANDOM", go to a randomly-selected room.
    cmp.w #2
    bne   .Done
    ; Convert the current room-index to an index in the destinations list
    lda   !currentRoom
    phx
    ldx   #$0000
    -
    cmp   DestinationRooms+2,x
    bcc   +
    inx
    inx
    bra   -
    +
    txa
    lsr
    pha
    ; Generate a random byte
    jsl   LongRandom
    and   #$00FF
    ; Add the previously-converted index
    clc
    adc   $01,s
    ; Divide this sum by DESTINATIONS_LENGTH and get the remainder
    sta   !WRDIVL
    pla
    sep   #$20
    lda.b #!DESTINATIONS_LENGTH
    sta   !WRDIVB
    ; Wait for the division to complete
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    ; Get the remainder
    rep   #$20
    lda   !RDMPYL
    asl
    tax
    lda   DestinationRooms,x
    ; Room found
    sta   !currentRoom
    asl
    tax
    lda   MapNumbers,x
    sta   !changeMap
    plx
.Done:
    rtl



WaitForVBlank:
    php
    rep   #$20
    pha
    lda   !memoryViewerOn
    beq   +
    jsr   DrawMemoryViewer
    +
    sep   #$20
    lda   !RDNMI
    -
    lda   !RDNMI
    bpl   -
    lda   !RDNMI
    rep   #$20
    pla
    plp
    rts



WaitForKeyup:
    -
    dec   !frameCounter
    jsr   WaitForVBlank
    bit   !JOY1L
    bne   -
    rts



WindowData:
    db $27, $FF, $00
    db $40, $24, $DC
    db $61, $24, $DC
    db $01, $FF, $00
    db $00

; Room-index to map-number mapping.
MapNumbers:
    dw $0101, $0101, $0101
    dw $0102, $0103, $0104
    dw $0201, $0201, $0201
    dw $0202, $0203, $0204, $0205, $0206, $0207, $0208
    dw $0301, $0302, $0302
    dw $0303, $0304, $0305, $0306
    dw $0401, $0401, $0402, $0403
    dw $0404, $0405, $0406, $0407
    dw $0501, $0502, $0503
    dw $0504, $0505, $0506, $0507, $0508
    dw $0601, $0602, $0603, $0603, $0604
    dw $0605, $0606, $0607, $0608
    dw $0702, $0703, $0704, $0705, $0706, $0707, $0708

; "Next room" values for each room-index.
; There's a "next room" value in this table for the room-with-two-exits in
; the Marahna temple, but it's just a placeholder. See "LoadNextRoom" for
; how that case is handled.
NextRooms:
    dw 3, 3, 3
    dw 4, 5, 6
    dw 9, 9, 9
    dw 10, 11, 12, 13, 14, 15, 16
    dw 17, 19, 19
    dw 20, 21, 22, 23
    dw 25, 25, 26, 27
    dw 28, 29, 30, 31
    dw 32, 33, 34
    dw 35, 36, 38, 38, 39
    dw 40, 41, 43, 43, 44
    dw 45, 46, 47, 48
    dw 49, 50, 51, 52, 53, 54, 0

; Eligible destination room-indexes when the on-exit action is "RANDOM".
; The terminating "$FFFF" simplifies some search code in "LoadNextRoom".
DestinationRooms:
    dw 0
    dw 3, 4, 5
    dw 6
    dw 9, 10, 11, 12, 13, 14, 15
    dw 16, 17
    dw 19, 20, 21, 22
    dw 23, 25, 26
    dw 27, 28, 29, 30
    dw 31, 32, 33
    dw 34, 35, 36, 37, 38
    dw 39, 40, 41, 43
    dw 44, 45, 46, 47
    dw 48, 49, 50, 51, 52, 53, 54
    dw $FFFF

TEXT_Cursor:
    db $3E, $00
TEXT_LeftArrow:
    db $3D, $00
TEXT_RightArrow:
    db $3C, $00
TEXT_ResumeGame:
    db "Resume game", $00
TEXT_RestoreHealth:
    db "Restore health", $00
TEXT_CountdownRunning:
    db "Countdown is RUNNING", $00
TEXT_CountdownPaused:
    db "Countdown is PAUSED", $00
TEXT_MemoryViewerOff:
    db "Memory viewer is OFF", $00
TEXT_MemoryViewerOn:
    db "Memory viewer is ON", $00
TEXT_OnRoomLoad:
    db "On room load...", $00
TEXT_AutoHealOff:
    db "- Auto-recovery OFF", $00
TEXT_AutoHealOn:
    db "- Auto-recovery ON", $00
TEXT_AutoSwordOff:
    db "- Sword upgrade OFF", $00
TEXT_AutoSwordOn:
    db "- Sword upgrade ON", $00
TEXT_AutoEasyOff:
    db "- PRO difficulty", $00
TEXT_AutoEasyOn:
    db "- NORMAL difficulty", $00
TEXT_LoadSelectedRoom:
    db "Load selected room", $00
TEXT_EraseAll:
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16, $0D
    db $0B, $16
    db $00

; Pointer table for magic descriptions.
MagicDescriptions:
    dw TEXT_MagicNone
    dw TEXT_MagicFire
    dw TEXT_MagicStardust
    dw TEXT_MagicAura
    dw TEXT_MagicLight

TEXT_MagicNone:
    db "No magic", $00
TEXT_MagicFire:
    db "Magical Fire", $00
TEXT_MagicStardust:
    db "Magical Stardust", $00
TEXT_MagicAura:
    db "Magical Aura", $00
TEXT_MagicLight:
    db "Magical Light", $00

; Pointer table for on-exit descriptions.
OnExitDescriptions:
    dw TEXT_OnExitRepeat
    dw TEXT_OnExitAdvance
    dw TEXT_OnExitRandom

TEXT_OnExitRepeat:
    db "On exit, REPEAT", $00
TEXT_OnExitAdvance:
    db "On exit, ADVANCE", $00
TEXT_OnExitRandom:
    db "On exit, RANDOM", $00

; Pointer table for room descriptions.
RoomDescriptions:
    dw TEXT_101, TEXT_101_CHECKPOINT, TEXT_101_AT_BOSS
    dw TEXT_102, TEXT_103, TEXT_104
    dw TEXT_201, TEXT_201_CHECKPOINT, TEXT_201_AT_BOSS
    dw TEXT_202, TEXT_203, TEXT_204, TEXT_205, TEXT_206, TEXT_207, TEXT_208
    dw TEXT_301, TEXT_302, TEXT_302_AT_BOSS
    dw TEXT_303, TEXT_304, TEXT_305, TEXT_306
    dw TEXT_401, TEXT_401_CHECKPOINT, TEXT_402, TEXT_403
    dw TEXT_404, TEXT_405, TEXT_406, TEXT_407
    dw TEXT_501, TEXT_502, TEXT_503
    dw TEXT_504, TEXT_505, TEXT_506, TEXT_507, TEXT_508
    dw TEXT_601, TEXT_602, TEXT_603, TEXT_603_CHECKPOINT, TEXT_604
    dw TEXT_605, TEXT_606, TEXT_607, TEXT_608
    dw TEXT_702, TEXT_703, TEXT_704, TEXT_705, TEXT_706, TEXT_707, TEXT_708

TEXT_101:
    db "101", $0D
    db "Forest", $0D
    db "Centaur Knight"
    db $00

TEXT_101_CHECKPOINT:
    db "101 checkpoint", $0D
    db "Forest", $0D
    db "Centaur Knight"
    db $00

TEXT_101_AT_BOSS:
    db "101 at boss", $0D
    db "Forest", $0D
    db "Centaur Knight"
    db $00

TEXT_102:
    db "102", $0D
    db "Caves I", $0D
    db "Skeltous"
    db $00

TEXT_103:
    db "103", $0D
    db "Caves II", $0D
    db "Endless climb"
    db $00

TEXT_104:
    db "104", $0D
    db "Caves III", $0D
    db "Minotaurus"
    db $00

TEXT_201:
    db "201", $0D
    db "Swamp", $0D
    db "Manticore"
    db $00

TEXT_201_CHECKPOINT:
    db "201 checkpoint", $0D
    db "Swamp", $0D
    db "Manticore"
    db $00

TEXT_201_AT_BOSS:
    db "201 at boss", $0D
    db "Swamp", $0D
    db "Manticore"
    db $00

TEXT_202:
    db "202", $0D
    db "Castle I", $0D
    db "Front gate"
    db $00

TEXT_203:
    db "203", $0D
    db "Castle II", $0D
    db "First elevator"
    db $00

TEXT_204:
    db "204", $0D
    db "Castle III", $0D
    db "Glowing cellar"
    db $00

TEXT_205:
    db "205", $0D
    db "Castle IV", $0D
    db "Second elevator"
    db $00

TEXT_206:
    db "206", $0D
    db "Castle V", $0D
    db "Atop the wall"
    db $00

TEXT_207:
    db "207", $0D
    db "Castle VI", $0D
    db "Yoku blocks"
    db $00

TEXT_208:
    db "208", $0D
    db "Castle VII", $0D
    db "Zeppelin Wolf"
    db $00

TEXT_301:
    db "301", $0D
    db "Desert I", $0D
    db "Shifting sands"
    db $00

TEXT_302:
    db "302", $0D
    db "Desert II", $0D
    db "Dagoba"
    db $00

TEXT_302_AT_BOSS:
    db "302 at boss", $0D
    db "Desert II", $0D
    db "Dagoba"
    db $00

TEXT_303:
    db "303", $0D
    db "Pyramid I", $0D
    db "Mummy crypt"
    db $00

TEXT_304:
    db "304", $0D
    db "Pyramid II", $0D
    db "Anubis statues"
    db $00

TEXT_305:
    db "305", $0D
    db "Pyramid III", $0D
    db "Elevator race"
    db $00

TEXT_306:
    db "306", $0D
    db "Pyramid IV", $0D
    db "Pharao"
    db $00

TEXT_401:
    db "401", $0D
    db "Mountains I", $0D
    db "Auto-scroller"
    db $00

TEXT_401_CHECKPOINT:
    db "401 checkpoint", $0D
    db "Mountains I", $0D
    db "Auto-scroller"
    db $00

TEXT_402:
    db "402", $0D
    db "Mountains II", $0D
    db "Waterfall"
    db $00

TEXT_403:
    db "403", $0D
    db "Mountains III", $0D
    db "Serpent"
    db $00

TEXT_404:
    db "404", $0D
    db "Volcano I", $0D
    db "Hall of giants"
    db $00

TEXT_405:
    db "405", $0D
    db "Volcano II", $0D
    db "Magma chamber"
    db $00

TEXT_406:
    db "406", $0D
    db "Volcano III", $0D
    db "Samurai archers"
    db $00

TEXT_407:
    db "407", $0D
    db "Volcano IV", $0D
    db "Fire Wheel"
    db $00

TEXT_501:
    db "501", $0D
    db "Jungle I", $0D
    db "Overgrown ruins"
    db $00

TEXT_502:
    db "502", $0D
    db "Jungle II", $0D
    db "Falling snakes"
    db $00

TEXT_503:
    db "503", $0D
    db "Jungle III", $0D
    db "Rafflasher"
    db $00

TEXT_504:
    db "504", $0D
    db "Temple I", $0D
    db "Stone elevator"
    db $00

TEXT_505:
    db "505", $0D
    db "Temple II", $0D
    db "Choose a path"
    db $00

TEXT_506:
    db "506", $0D
    db "Temple III", $0D
    db "Left path"
    db $00

TEXT_507:
    db "507", $0D
    db "Temple IV", $0D
    db "Right path"
    db $00

TEXT_508:
    db "508", $0D
    db "Temple V", $0D
    db "Kalia"
    db $00

TEXT_601:
    db "601", $0D
    db "Arctic I", $0D
    db "Snowfield"
    db $00

TEXT_602:
    db "602", $0D
    db "Arctic II", $0D
    db "Ice-cube rafts"
    db $00

TEXT_603:
    db "603", $0D
    db "Arctic III", $0D
    db "Ride the sled"
    db $00

TEXT_603_CHECKPOINT:
    db "603 checkpoint", $0D
    db "Arctic III", $0D
    db "Ride the sled"
    db $00

TEXT_604:
    db "604", $0D
    db "Arctic IV", $0D
    db "Merman Fly"
    db $00

TEXT_605:
    db "605", $0D
    db "Great Tree I", $0D
    db "Tree entrance"
    db $00

TEXT_606:
    db "606", $0D
    db "Great Tree II", $0D
    db "Lower trunk"
    db $00

TEXT_607:
    db "607", $0D
    db "Great Tree III", $0D
    db "Upper trunk"
    db $00

TEXT_608:
    db "608", $0D
    db "Great Tree IV", $0D
    db "Arctic Wyvern"
    db $00

TEXT_702:
    db "702", $0D
    db "Death Heim", $0D
    db "Minotaurus"
    db $00

TEXT_703:
    db "703", $0D
    db "Death Heim", $0D
    db "Zeppelin Wolf"
    db $00

TEXT_704:
    db "704", $0D
    db "Death Heim", $0D
    db "Pharao"
    db $00

TEXT_705:
    db "705", $0D
    db "Death Heim", $0D
    db "Fire Wheel"
    db $00

TEXT_706:
    db "706", $0D
    db "Death Heim", $0D
    db "Kalia"
    db $00

TEXT_707:
    db "707", $0D
    db "Death Heim", $0D
    db "Arctic Wyvern"
    db $00

TEXT_708:
    db "708", $0D
    db "Death Heim", $0D
    db "Tanzra"
    db $00

Credits:
    db "ActRaiser Practice ROM v0.4", $0D
    db "Osteoclave", $0D
    db "2020-10-26"
    db $00
