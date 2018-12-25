;boiler plate directives
  .inesprg 1 			;# of 16kb PRG banks
  .ineschr 1			;# of 8kb CHR banks
  .inesmap 0			;NES Mapper
  .inesmir 1			;VRAM mirroring of banks

  .rsset $0000
pointerBackgroundLowByte .rs 1
pointerBackgroundHighByte .rs 1

;i attempt to use these bytes for indirect indexed addressing of background data
gridLocationLowByte .rs 1
gridLocationHighByte .rs 1

;this is a bitmask to keep track of whether a user is holding down a button
;from left to right, the bits reppresent a, b, select, start, d-pad up,
;d-pad down, d-pad left, d-pad right
current_controller_state .rs 1

buttons_pressed .rs 1
buttons_held .rs 1
dpad_delay_auto_shift_active .rs 1
dpad_delay_auto_shift_counter .rs 1
sustained_movement_counter .rs 1


;16 frame delay from initial movement to sustained movement
BUTTON_ACTIVE_DELAY1 = $18
;4 frame delay between sustained movement to throttle the speed of the sprites
BUTTON_ACTIVE_DELAY2 = $08

A_BUTTON = %10000000
B_BUTTON =%01000000
SELECT_BUTTON = %00100000
START_BUTTON = %00010000
UP_BUTTON = %00001000
DOWN_BUTTON = %00000100
LEFT_BUTTON = %00000010
RIGHT_BUTTON = %00000001
DPAD_BUTTONS = %00001111

controller1 = $4016
controller2 = $4017

playerSquare1y = $0300
playerSquare1x = $0303
playerSquare2y = $0304
playerSquare2x = $0307
playerSquare3y = $0308
playerSquare3x = $030B
playerSquare4y = $030C
playerSquare4x = $030F

spriteMovementYOffset .rs 1
spriteMovementXOffset .rs 1
spriteMovementXNegOffset .rs 1

playerGridPos1 .rs 1
playerGridPos1_hb .rs 1

playerNextGridPos1 .rs 1
playerNextGridPos1_hb .rs 1

playerTempGridStart .rs 1
playerTempGridStart_hb .rs 1

playerTempGridPos1 .rs 1
playerTempGridPos1_hb .rs 1

adjacentSquareOffset .rs 1
nextGridPosValidBool .rs 1






;bank for game logic
  .bank 0
  .org $C000

RESET:
  JSR LoadBackground
  JSR LoadPalettes
  LDA #%10000000
  STA $2000
  LDA #%00011110
  STA $2001
  LDA #$00
  STA $2006
  STA $2006
  STA $2005
  STA $2005
  JSR LoadSprites

  LDA #$CF
  STA playerGridPos1
  LDA #$00
  STA playerGridPos1_hb
  STA nextGridPosValidBool

GameLoop:
  JMP GameLoop

LoadBackground:

  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006

  LDA #LOW(background)
  STA pointerBackgroundLowByte
  LDA #HIGH(background)
  STA pointerBackgroundHighByte

  LDX #$00
  LDY #$00
.Loop:
  LDA [pointerBackgroundLowByte], y
  STA $2007

  INY
  CPY #$00
  BNE .Loop

  INC pointerBackgroundHighByte
  INX
  CPX #$04
  BNE .Loop
  RTS

LoadPalettes:
  LDA $2000
  LDA #$3F
  STA $2006
  LDA #$00
  STA $2006

  LDX #$00
.Loop:
  LDA palettes, x
  STA $2007
  INX
  CPX #$20
  BNE .Loop
  RTS

LoadSprites:
  LDX #$00
.Loop
  LDA sprites, x
  STA $0300, x
  INX
  CPX #$10
  BNE .Loop
  RTS

ReadController1:
  LDX buttons_held ;register x saves buttons held from last frame
  LDY buttons_pressed ; register y saves buttons initially pressed last frame

  LDA #$01
  STA controller1
  STA current_controller_state
  LSR A
  STA controller1
.loop:
  LDA controller1
  LSR A
  ROL current_controller_state
  BCC .loop

  ;wipe out buttons_held and buttons_pressed for any button not currently active
  LDA buttons_held
  AND current_controller_state
  STA buttons_held
  LDA buttons_pressed
  AND current_controller_state
  STA buttons_pressed

  ;wipe out delay auto shift status for any D-Pad button not active
  LDA dpad_delay_auto_shift_active
  AND current_controller_state
  AND DPAD_BUTTONS
  STA dpad_delay_auto_shift_active
  BEQ SkipResetDASTimer
  ; reset counter to 0 if no dpad buttons are active
  LDA #$00
  STA dpad_delay_auto_shift_counter
SkipResetDASTimer:
  ;pressed buttons from last frame that are still pressed are now held
  TYA ; fetch last frame button pressed from Y register
  AND current_controller_state ; clear any buttons not currently active
  ORA buttons_held
  STA buttons_held

  ;buttons that are currently active but not held should be considered pressed
  ;assuming buttons_held is still in accumulator a
  EOR current_controller_state
  STA buttons_pressed

  ;calculate delay auto shift status for d-pad
  LDA buttons_held
  AND #DPAD_BUTTONS
  TAX ; store this currently held dpad buttons in case we need it later
  BEQ SkipIncrementDASTimer ; skip if no d-pad buttons are held
  LDA dpad_delay_auto_shift_active
  CMP #$00
  BNE SkipIncrementDASTimer ; if DAS is already active, don't increment
  INC dpad_delay_auto_shift_counter
  LDA dpad_delay_auto_shift_counter
  CMP #BUTTON_ACTIVE_DELAY1
  BCC SkipIncrementDASTimer
  TXA
  STA dpad_delay_auto_shift_active

SkipIncrementDASTimer:

  RTS

IsAdjacentSquareOpen:
  LDA #LOW(background)
  STA gridLocationLowByte
  LDA #HIGH(background)
  STA gridLocationHighByte

  LDA playerGridPos1
  CLC
  ADC adjacentSquareOffset
  STA playerTempGridPos1

  LDA playerGridPos1_hb
  ADC $00
  STA playerTempGridPos1_hb

  ADC gridLocationHighByte
  STA gridLocationHighByte

  LDY playerTempGridPos1
  LDA [gridLocationLowByte], y
  CMP #$00
  BNE .NotOpen
.IsOpen:
  STA nextGridPosValidBool
  RTS
.NotOpen:
  LDA #$FF
  STA nextGridPosValidBool
  RTS

IsLeftAdjacentSquareOpen:
  LDA #LOW(background)
  STA gridLocationLowByte
  LDA #HIGH(background)
  STA gridLocationHighByte

  LDA playerGridPos1
  SEC
  SBC adjacentSquareOffset
  STA playerTempGridPos1

  LDA playerGridPos1_hb
  SBC $00
  STA playerTempGridPos1_hb

  ADC gridLocationHighByte
  STA gridLocationHighByte

  LDY playerTempGridPos1
  LDA [gridLocationLowByte], y
  CMP #$00
  BNE .NotOpen
.IsOpen:
  STA nextGridPosValidBool
  RTS
.NotOpen:
  LDA #$FF
  STA nextGridPosValidBool
  RTS

MoveSpritesByOffset:
  LDA spriteMovementYOffset
  CMP #$00
  BEQ SkipYMovement
  LDA playerSquare1y
  CLC
  ADC spriteMovementYOffset
  STA playerSquare1y

  LDA playerSquare2y
  CLC
  ADC spriteMovementYOffset
  STA playerSquare2y

  LDA playerSquare3y
  CLC
  ADC spriteMovementYOffset
  STA playerSquare3y

  LDA playerSquare4y
  CLC
  ADC spriteMovementYOffset
  STA playerSquare4y
SkipYMovement:
  LDA spriteMovementXOffset
  CMP #$00
  BEQ SkipXMovement
  LDA playerSquare1x
  CLC
  ADC spriteMovementXOffset
  STA playerSquare1x

  LDA playerSquare2x
  CLC
  ADC spriteMovementXOffset
  STA playerSquare2x

  LDA playerSquare3x
  CLC
  ADC spriteMovementXOffset
  STA playerSquare3x

  LDA playerSquare4x
  CLC
  ADC spriteMovementXOffset
  STA playerSquare4x
SkipXMovement:
  LDA spriteMovementXNegOffset
  CMP #$00
  BEQ SkipNegXMovement

  LDA playerSquare1x
  SEC
  SBC spriteMovementXNegOffset
  STA playerSquare1x

  LDA playerSquare2x
  SEC
  SBC spriteMovementXNegOffset
  STA playerSquare2x

  LDA playerSquare3x
  SEC
  SBC spriteMovementXNegOffset
  STA playerSquare3x

  LDA playerSquare4x
  SEC
  SBC spriteMovementXNegOffset
  STA playerSquare4x

SkipNegXMovement:
  RTS


MovePlayerPiece:
  INC sustained_movement_counter
ReadLeft:
  LDA buttons_pressed
  AND #LEFT_BUTTON
  BNE MovePlayerPieceLeft

  LDA dpad_delay_auto_shift_active
  AND #LEFT_BUTTON
  BEQ EndReadLeft

  LDA sustained_movement_counter
  CMP #BUTTON_ACTIVE_DELAY2
  BCC EndReadLeft

MovePlayerPieceLeft:

  LDA #$01
  STA adjacentSquareOffset
  JSR IsLeftAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveLeft

  LDA playerTempGridPos1
  STA playerNextGridPos1
  LDA playerTempGridPos1_hb
  STA playerNextGridPos1_hb

  LDA #$1F
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveLeft

  LDA #$08
  STA spriteMovementXNegOffset
  LDA #$00
  STA spriteMovementYOffset
  STA spriteMovementXOffset
  JSR MoveSpritesByOffset

  LDA playerNextGridPos1
  STA playerGridPos1

  ;set counter to zero since we're about to go into DAS
  LDA #$00
  STA sustained_movement_counter

  LDA playerNextGridPos1
  STA playerGridPos1
  LDA playerNextGridPos1_hb
  STA playerGridPos1_hb
DontMoveLeft:
EndReadLeft:

ReadRight:
  LDA buttons_pressed
  AND #RIGHT_BUTTON
  BNE MovePlayerPieceRight

  LDA dpad_delay_auto_shift_active
  AND #RIGHT_BUTTON
  BEQ EndReadRight

  LDA sustained_movement_counter
  CMP #BUTTON_ACTIVE_DELAY2
  BCC EndReadRight

MovePlayerPieceRight:

  LDA #$01
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveRight
  LDA playerTempGridPos1
  STA playerNextGridPos1
  LDA playerTempGridPos1_hb
  STA playerNextGridPos1_hb

  LDA #$03
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveRight

  LDA #$21
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveRight

  LDA #$08
  STA spriteMovementXOffset
  LDA #$00
  STA spriteMovementYOffset
  STA spriteMovementXNegOffset
  JSR MoveSpritesByOffset

  LDA playerNextGridPos1
  STA playerGridPos1
  LDA playerNextGridPos1_hb
  STA playerGridPos1_hb

DontMoveRight:

  ;set counter to zero since we're about to go into DAS
  LDA #$00
  STA sustained_movement_counter
EndReadRight:


ReadDown:
  LDA buttons_pressed
  AND #DOWN_BUTTON
  BNE MovePlayerPieceDown

  JMP EndReadDown

  LDA dpad_delay_auto_shift_active
  AND #DOWN_BUTTON
  BEQ EndReadDown

  LDA sustained_movement_counter
  CMP #BUTTON_ACTIVE_DELAY2
  BCC EndReadDown
MovePlayerPieceDown:

  LDA #$20
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveDown
  LDA playerTempGridPos1
  STA playerNextGridPos1
  LDA playerTempGridPos1_hb
  STA playerNextGridPos1_hb

  LDA #$40
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveDown

  LDA #$21
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveDown

  LDA #$22
  STA adjacentSquareOffset
  JSR IsAdjacentSquareOpen
  LDA nextGridPosValidBool
  CMP $00
  BNE DontMoveDown

  LDA #$08
  STA spriteMovementYOffset
  LDA #$00
  STA spriteMovementXOffset
  STA spriteMovementXNegOffset
  JSR MoveSpritesByOffset

  LDA playerNextGridPos1
  STA playerGridPos1
  LDA playerNextGridPos1_hb
  STA playerGridPos1_hb
DontMoveDown:
  ;set counter to zero since we're about to go into DAS
  LDA #$00
  STA sustained_movement_counter
EndReadDown:


  RTS



NMI:
  LDA #$00
  STA $2003
  LDA #03
  STA $4014
  JSR ReadController1
  JSR MovePlayerPiece
  RTI


  .bank 1
  .org $E000

background:
  .include "graphics/background.asm"

palettes:
  .include "graphics/palettes.asm"

sprites:
  .include "graphics/sprites.asm"

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0

;bank for character data (sprites/backgrounds)
  .bank 2
  .org $0000
  .incbin "graphics.chr"
