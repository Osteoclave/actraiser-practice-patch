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
!pauseStatus     = $0332

; Vanilla labels
PrintText  = $02BF60
UpdateHUD  = $02C206
MagicIcons = $06A400

; New variables
; In vanilla, 7E024C-0281 contains the "offering" inventories for each town.
; The practice ROM never enters town-building mode, so we can repurpose this
; memory safely.
!menuCursor  = $024C
!heldButton  = $024E
!heldCounter = $0250
!magicIcon   = $0252
!roomIndex   = $0254

; New constants
; Number of items in the various selectable menus.
!MENU_LENGTH  = 5
!MAGIC_LENGTH = 5
!ROOMS_LENGTH = 48
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

; Make the title screen menu only have "START" as an option.
org   $02A70D
nop
nop

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

; Update the fixed string used by the memory viewer.
org   $02BE99
db    "X 0000 Y 0000      R 00 F 0000", $00

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
org   $008304
jsl   UpdateMemoryViewer

; Skip the "descending ball of light brings statue to life" animation.
org   $02AB0D
stz   $00FC

; Replace the existing Start-button pause handler.
org   $008066
jsl   NewPauseHandler

; In the event of player death, respawn on the same map.
org   $02BD61
nop
nop
lda   !currentMap+1

; Upon leaving a room, warp back to the room you just left.
org   $00B030
lda   #$0102
org   $00B03B
lda   #$0103
org   $00B92B
lda   #$0202
org   $00B939
lda   #$0203
org   $00B947
lda   #$0204
org   $00B955
lda   #$0205
org   $00B963
lda   #$0206
org   $00B971
lda   #$0207
org   $00C15E
lda   #$0301
org   $00C16C
lda   #$0303
org   $00C186
lda   #$0304
org   $00C19C
lda   #$0305
org   $00CDEB
lda   #$0401
org   $00CDF9
lda   #$0402
org   $00CE0F
lda   #$0404
org   $00CE1D
lda   #$0405
org   $00CE33
lda   #$0406
org   $00E6C6
lda   #$0501
org   $00E6D4
lda   #$0502
org   $00E6EA
lda   #$0504
org   $00E6F8
ldy   #$0505
org   $00E702
nop
org   $00E71C
lda   !currentMap
xba
org   $00E766
lda   #$0601
org   $00E774
lda   #$0602
org   $00E78A
lda   #$0603
org   $00E7A0
lda   #$0605
org   $00E7AB
lda   #$0606
org   $00E7B6
lda   #$0607

; Upon completing an Act, don't increment the "Acts completed" counter and
; don't advance to the next Act. Just reload the current map.
org   $008788
lda   !currentMap
xba
jmp   $8796

; Upon defeating a boss in the boss rush, don't increment the "bosses
; defeated in the boss rush" counter. Just reload the current map.
org   $00FEEC
lda   !currentMap
xba
bra   $07
org   $00FF00
bra   $05

; Remove the sword upgrade when changing maps.
org   $008266
rep   #$20
lda   !currentMap
pha
lda   !changeMap
xba
sta   !currentMap
sep   #$20
stz   !swordUpgrade

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



; Updated map metadata: each map now loads all of its required assets.
org    $1F8000
incsrc map_metadata_usa.asm



UpdateMemoryViewer:
    ; The memory viewer wasn't ready yet when v0.1 released.
    rtl
    ; The following code was inaccessible but not removed.
    ; It borrows heavily from the existing debug-mode code.
    ; See 00/81BE in the vanilla ROM for comparison.
    php
    rep   #$30
    phy
    phx
    pha
    sep   #$20
    ldy   $8A
    ldx   #$0002
    lda   $0003,y
    jsr   PrintByte
    lda   $0002,y
    jsr   PrintByte
    ldx   #$0009
    lda   $0005,y
    jsr   PrintByte
    lda   $0004,y
    jsr   PrintByte
    ldx   #$0015
    lda   !rng
    jsr   PrintByte
    ldx   #$001A
    lda   !frameCounter+1
    jsr   PrintByte
    lda   !frameCounter
    jsr   PrintByte
    rep   #$20
    lda   #$1A01
    ldy   #$035D
    jsl   PrintText
    pla
    plx
    ply
    plp
    rtl



PrintByte:
    phy
    ; Clear high bits of A
    xba
    lda   #$00
    xba
    ; First digit
    pha
    lsr
    lsr
    lsr
    lsr
    tay
    lda   $8228,y
    sta   $035D,x
    inx
    pla
    ; Second digit
    and   #$0F
    tay
    lda   $8228,y
    sta   $035D,x
    inx
    ply
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
    ; Determine the room index from the current map number
    lda   !currentMap
    xba
    ldx   #$0000
    -
    cmp   MapNumbers,x
    beq   +
    inx
    inx
    bra   -
    +
    txa
    lsr
    tax
    sta   !roomIndex

    ; Draw the menu
    jsr   DrawMenu

    ; Wait for the Start button to be released
    lda   #!JOYPAD_START
    jsr   WaitForKeyup

.Loop:
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
    bne   .MagicSelector
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

.MagicSelector:
    cmp.w #2
    bne   .RoomSelector

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
    bra   .RedrawMenu
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
    bra   .RedrawMenu
    ++

    bra   .NextFrame

.RoomSelector:
    cmp.w #3
    bne   .LoadSelectedRoom

    ; Room selector behaviour: Left button
    lda   #!JOYPAD_LEFT
    jsr   CheckButton
    bcc   ++
    lda   !roomIndex
    dec
    bpl   +
    lda.w #!ROOMS_LENGTH-1
    +
    sta   !roomIndex
    bra   .RedrawMenu
    ++

    ; Room selector behaviour: Right button
    lda   #!JOYPAD_RIGHT
    jsr   CheckButton
    bcc   ++
    lda   !roomIndex
    inc
    cmp.w #!ROOMS_LENGTH
    bcc   +
    lda.w #0
    +
    sta   !roomIndex
    bra   .RedrawMenu
    ++

    bra   .NextFrame

.LoadSelectedRoom:
    cmp.w #4
    bne   .NextFrame
    lda   #!JOYPAD_B
    bit   !JOY1L
    beq   +
    ; Prevent this B-press from making the player jump
    ; The room transition resets "ignoreInput" (i.e. no inputs ignored), so
    ; we can't use it like we did in ".ResumeGame" above. Instead, we use
    ; the more aggressive "discardInput".
    trb   !discardInput
    lda   !roomIndex
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

    ; Magic selector
    lda   !equippedMagic
    and   #$00FF
    asl
    tax
    lda   MagicDescriptions,x
    tay
    lda   #$0809
    jsl   PrintText
    ; Arrows
    ldy.w #TEXT_LeftArrow
    lda   #$0807
    jsl   PrintText
    ldy.w #TEXT_RightArrow
    lda   #$081A
    jsl   PrintText

    ; Room selector
    lda   !roomIndex
    asl
    tax
    lda   RoomDescriptions,x
    tay
    lda   #$0A09
    jsl   PrintText
    ; Arrows
    ldy.w #TEXT_LeftArrow
    lda   #$0B07
    jsl   PrintText
    ldy.w #TEXT_RightArrow
    lda   #$0B1A
    jsl   PrintText

    ; Load selected room
    ldy.w #TEXT_LoadSelectedRoom
    lda   #$0E07
    jsl   PrintText

    ; Cursor
    ldy.w #TEXT_Cursor
    lda   !menuCursor
    cmp.w #0
    bne   +
    lda   #$0505
    +
    cmp.w #1
    bne   +
    lda   #$0605
    +
    cmp.w #2
    bne   +
    lda   #$0805
    +
    cmp.w #3
    bne   +
    lda   #$0B05
    +
    cmp.w #4
    bne   +
    lda   #$0E05
    +
    jsl   PrintText

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



WaitForVBlank:
    php
    sep   #$20
    pha
    lda   !RDNMI
    -
    lda   !RDNMI
    bpl   -
    lda   !RDNMI
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
    db $59, $24, $DC
    db $01, $FF, $00
    db $00

; Room-index to map-number mapping.
MapNumbers:
    dw $0101
    dw $0102, $0103, $0104
    dw $0201
    dw $0202, $0203, $0204, $0205, $0206, $0207, $0208
    dw $0301, $0302
    dw $0303, $0304, $0305, $0306
    dw $0401, $0402, $0403
    dw $0404, $0405, $0406, $0407
    dw $0501, $0502, $0503
    dw $0504, $0505, $0506, $0507, $0508
    dw $0601, $0602, $0603, $0604
    dw $0605, $0606, $0607, $0608
    dw $0702, $0703, $0704, $0705, $0706, $0707, $0708

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

; Pointer table for room descriptions.
RoomDescriptions:
    dw TEXT_101
    dw TEXT_102, TEXT_103, TEXT_104
    dw TEXT_201
    dw TEXT_202, TEXT_203, TEXT_204, TEXT_205, TEXT_206, TEXT_207, TEXT_208
    dw TEXT_301, TEXT_302
    dw TEXT_303, TEXT_304, TEXT_305, TEXT_306
    dw TEXT_401, TEXT_402, TEXT_403
    dw TEXT_404, TEXT_405, TEXT_406, TEXT_407
    dw TEXT_501, TEXT_502, TEXT_503
    dw TEXT_504, TEXT_505, TEXT_506, TEXT_507, TEXT_508
    dw TEXT_601, TEXT_602, TEXT_603, TEXT_604
    dw TEXT_605, TEXT_606, TEXT_607, TEXT_608
    dw TEXT_702, TEXT_703, TEXT_704, TEXT_705, TEXT_706, TEXT_707, TEXT_708

TEXT_101:
    db "101", $0D
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
    db "ActRaiser Practice ROM v0.1", $0D
    db "Osteoclave", $0D
    db "2020-10-09"
    db $00