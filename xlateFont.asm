        .list
        .mlist

; **************************************************************************
;
; System Card V3.00 Patches to include Translate font (8x12 and 8x16)
;
; **************************************************************************

JPN_SYSCARD     =       1


                .bank   $0
                .org    $0000

        .if     JPN_SYSCARD

                .incbin "syscard3.pce.jpn"

VERPTCH         =       $C868
VERTGT          =       $C950
VERORG          =       $CDA0

FNTPTCH         =       $E060
ORGTRGT         =       $F124
FNTERR          =       $F129
FNTORG0         =       $FEC4

        .else

                .incbin	"syscard3.pce.usa"

VERPTCH         =       $C868
VERTGT          =       $C943
VERORG          =       $CD30

FNTPTCH         =       $E060
ORGTRGT         =       $F13D
FNTERR          =       $F142
FNTORG0         =       $FEDD

        .endif

VERBANK         =       1       ; Bank where version ID appears
FONTBANK        =       1       ; We are putting the font code in Bank 1

_AL             =       $F8     ; input = SJIS code LSB
_AH             =       $F9     ; input = SJIS code MSB (or ASCII)
_BL             =       $FA     ; input = target buffer LSB
_BH             =       $FB     ; input = target buffer MSB
_DH             =       $FF     ; input = character set
                                ; 0 = 16x16
                                ; 1 = 12x12
                                ; 2 = 8x16 (NEW !!)
                                ; 3 = 8x12 (NEW !!)

BASEADDR_MSB    =       $FC
BANK_STORE      =       $22BA   ; syscard's EX_GETFNT puts old bank here
RET_CODE        =       $EE
SRCLOC          =       $EC
SRCLOC_L        =       $EC
SRCLOC_H        =       $ED


                .bank   0
                .org    FNTPTCH
                JMP     FNTORG0

                .org    FNTORG0
                LDA     <_DH
                CMP     #$2             ; 0=16x16
                                        ; 1=12x12
                BCC     NORMAL
                CMP     #$4             ; 2=8x16
                                        ; 3=8x12
                BCC     BNKMAP
                JMP     FNTERR          ; other value

NORMAL:         JMP     ORGTRGT         ; original instruction

BNKMAP:         LDA     #$C0            ; Presumptive location where
                                        ; bank 1 will be mapped

                STA     <BASEADDR_MSB   ; Store base addr

                LDA     <_BH            ; MSB of target buffer
                SEC
                CMP     #$C0            ; is it a conflict ?
                BCS     .ALTMAP

                TMA6                    ; store old bank
                STA     BANK_STORE
                LDA     #FONTBANK       ; swap in FONT BANK
                TAM6
                JSR     FNTORG1         ; our font routine
                LDA     BANK_STORE      ; swap original bank back in
                TAM6
                BRA     EXIT

.ALTMAP:        LDA     #$60            ; base location ($6000 range)
                STA     <BASEADDR_MSB

                TMA3                    ; store old bank
                STA     BANK_STORE
                LDA     #FONTBANK       ; swap in FONT BANK
                TAM3
                JSR     FNTORG1-$6000   ; our font routine
                LDA     BANK_STORE      ; swap original bank back in
                TAM3

EXIT:
                LDA     <RET_CODE
                RTS


; **************************************************************************
;
; Now, add some identification information
;
; **************************************************************************

; This string is here so that games can check version ID
; to ensure that they don't try to run on a card without
; the functionality.  So, it's at a fixed location.
;
; It may be sufficient to check only the first two letters ('NU')
; 
                .bank   0
                .org    $FFAA
                .db     "NUFONT"

;
; Now, we patch the screen paint function to print out
; an additional identification string
;
                .bank   VERBANK

                .org    VERPTCH
                JSR     VERORG

                .org    VERORG

                JSR     VERTGT
                LDA     #LOW(VERSTR)
                STA     <_AL
                LDA     #HIGH(VERSTR)
                STA     <_AH
                JSR     VERTGT
                RTS

VERSTR:         .db     $00             ; color attribute
                .db     $13,$0f         ; x, y position on screen
                .db     "NUFONT 1.00"
                .db     $ff             ; string end
                .db     $ff             ; string list end

ENDVER:


; **************************************************************************
;
; The print function lives substantially in this bank and must be
; relocatable, as the target buffer's RAM location is not known
; until runtime (and this can't occupy the same bank)
;
; **************************************************************************

        .if     FONTBANK = VERBANK
                .bank   FONTBANK        ; if same bank, just continue
                .org    ENDVER
        .else
                .bank   FONTBANK        ; only needed if relocated
                .org    $C000           ; to a new empty bank
        .endif

FONT1:          .incbin "font8x16.bin"
FONT2:          .incbin "font8x12.bin"

FNTORG1:
                LDA     #1
                STA     <RET_CODE       ; set presumptive error code

                LDA     <_AH            ; ASCII will be stored in MSB
.CHK1:          CMP     #$80
                BCC     .CHK2
                RTS

.CHK2:          CMP     #$20
                BCS     .CHKOK
                RTS

.CHKOK:         STZ     <RET_CODE       ; ASCII OK - not an error now
	
                SEC                     ; set up new value range
                SBC     #$20
                STA     <_AL
                STZ     <_AH

                LDA     <_DH
                CMP     #$2             ; if 8x12 font, used different
                                        ; offset calculation
                BEQ     .WID8X16

                LDA     <_AL
                STA     <SRCLOC_L       ; store temporarily
                LDA     <_AH
                STA     <SRCLOC_H

                ASL     <_AL            ; _AX = _AX * 2
                ROL     <_AH

                CLC
                LDA     <SRCLOC_L
                ADC     <_AL
                STA     <_AL
                LDA     <SRCLOC_H
                ADC     <_AH
                STA     <_AH            ; Now, _AX = (orig _AX) * 3

                ASL     <_AL            ; Now, _AX = (orig _AX) * 6
                ROL     <_AH

                ASL     <_AL            ; Now, _AX = (orig _AX) * 12
                ROL     <_AH

                LDA     #LOW(FONT2)     ; character width table
                STA     <SRCLOC_L
                LDA     #HIGH(FONT2) & $1F
                CLC
                ADC     <BASEADDR_MSB   ; base address
                STA     <SRCLOC_H

                LDX     #$0C            ; loop setup - 12 pix tall
                BRA     ADD

.WID8X16:       LDX     #4
.LOOP1:         ASL     <_AL            ; 16 bytes per character
                ROL     <_AH
                DEX
                BNE     .LOOP1

                LDA     #LOW(FONT1)     ; set up base address for font
                STA     <SRCLOC_L
                LDA     #HIGH(FONT1) & $1F
                CLC
                ADC     <BASEADDR_MSB   ; add base memory offset
                STA     <SRCLOC_H

                LDX     #$10            ; loop setup - 16 pix tall
	
ADD:            CLC                     ; add character offset to base
                LDA     <_AL
                ADC     <SRCLOC_L
                STA     <SRCLOC_L
                LDA     <_AH
                ADC     <SRCLOC_H
                STA     <SRCLOC_H

                LDY     #0
.CPYLP:         LDA     [SRCLOC]        ; get byte
                STA     [_BL],Y
                INY
                CLA                     ; right side is empty
                STA     [_BL],Y
                INY

                CLC
                LDA     <SRCLOC_L       ; increment font source pointer
                ADC     #1
                STA     <SRCLOC_L
                LDA     <SRCLOC_H
                ADC     #0
                STA     <SRCLOC_H
                DEX
                BNE     .CPYLP

                LDA     <_DH
                CMP     #$3
                BNE     .RET

                LDX     #8              ; Need to fill remainder of buffer
                CLA
.CPYLP2:        STA     [_BL],Y
                INY
                DEX
                BNE     .CPYLP2

.RET:           RTS

