;*********************************
; LCD + Keypad + Output
; Written by: Marc Goudge
; February 1st 2014
;*********************************

list p=16f877
#include <p16f877.inc>
#include <lcd.inc>
__CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_ON & _HS_OSC & _WRT_ENABLE_ON & _CPD_OFF & _LVP_OFF

#define RS      PORTD, 2
#define E       PORTD, 3

;***************Registers for the Sensor results/algorithms
lights_done    EQU 0x20
sensor_count   EQU 0x21
light_previous EQU 0x22

;***************My General Purpose Registers
key_result    EQU    0x40
Table_Counter EQU    0x41
current_mode  EQU    0x42

;***************Specific to the EEPROM Usage
total_number  EQU    0x50
eeprom_address  EQU  0x51

;***************Registers used for special_divide
quotient    EQU  0x60


;***************************************
; Display macro
;***************************************
Display macro	Message
		local	loop_
		local 	end_
		clrf	Table_Counter
		clrw
loop_	movf	Table_Counter,W
		call 	Message
		xorlw	B'00000000' ;check WORK reg to see if 0 is returned
		btfsc	STATUS, Z
		goto	end_
		call	WR_DATA
		incf	Table_Counter,F
		goto	loop_
end_
		endm

        ;beginning of the code goes here.
        ORG     0x0000
        goto    init

        ;set here so you can place the tables where needed

;***************************************
; EEPROM Writing macro
;***************************************
EE_Write macro
         ;first part of the code that sets up the data to write
         movf   eeprom_address, W
         movwf  EEADR
         movf   eeprom_data, W
         movwf  EEDATA

         ;change the bits, enable writing and disable interupts
         bsf STATUS, RP0 ; Bank1
         bsf EECON1, WREN ; Enable Write

         movlw 55h ;
         movwf EECON2 ; 55h must be written to EECON2
         movlw AAh ; to start write sequence
         movwf EECON2 ; Write AAh
         bsf EECON1, WR ; Set WR bit begin write

endm

;***************************************
; Tables with different menus/key presses
;***************************************

MainMenu
		addwf	PCL,F
		dt		"Main Menu 1: Out", 0

MainMenu2
		addwf	PCL,F
		dt		"2: Light Sensing", 0

Motor
		addwf	PCL,F
		dt		"Motor is on.", 0

NonSet1
		addwf	PCL,F
		dt		"Standby Mode", 0

NonSet2
		addwf	PCL,F
		dt		"Waiting...", 0

Signal
		addwf	PCL,F
		dt		"Signal Received", 0


KeyB
		addwf	PCL,F
		dt		"Key: 2 RC7: On", 0

KeyA
		addwf	PCL,F
		dt		"Key: 1 RC5: On", 0

KeyLine2
		addwf	PCL,F
		dt		"Any Key Returns.", 0

org     0x300

;*******************initial things****************************

;first part of code does:
;changes the bank to bank 1 (needed to set the port settings)
;using TRISX, sets all the ports to output
;changes back to bank0.

init
        ;*****************section for variable declaration/initializing
        clrf    eeprom_address ; setting the base eeprom_address to zero
        incf    eeprom_address, F ; setting it to 1 as the 0th is for number

        ;******************section for bank setting/specific bits

        ;*****BANK 1 SPECIFICATIONS
        clrf    INTCON         ; No interrupts
        bsf     STATUS, RP0    ; bank 1 now
        clrf    TRISA
        bsf     TRISA, 0       ; Set pin0 of port a
        movlw   b'11110010'    ; Set required keypad inputs
        movwf   TRISB
        clrf    TRISC
        clrf    TRISD          ; all three ports now set to output
        movlw   0x07
        movwf   ADCON1 ; set to digital input

        ;*****BANK 0 SPECIFICATIONS
        bcf     STATUS, RP0
        clrf    PORTA
        clrf    PORTB
        clrf    PORTC
        clrf    PORTD
        call    InitLCD
        goto    main_menu

main_menu
        Display     MainMenu
        call        Switch_Lines
        Display     MainMenu2

menu_loop
         ;checks to wait for button presses
         ;and puts the button press inside the appropriate register

         btfss		PORTB, 1     ;Wait until data is available from the keypad
         goto		$-1
         swapf		PORTB, W     ;Read PortB<7:4> into W<3:0>
         andlw		0x0F
         movwf      key_result  ;store the key result
         movlw      0x01
         addwf      key_result, f
         btfsc		PORTB,1     ;Wait until key is released
         goto		$-1
         goto       key_logic

key_logic
        ; logic for determining what key was pressed.
        ; note: SEPERATE EACH KEY PRESS
        ; IT WILL NOT WORK IF YOU INCLUDE MACROS

        decfsz	key_result, f
        goto    $+2
        goto    key_a
        decfsz  key_result, f
        goto    $+2
        goto    key_b
        goto    menu_loop


key_a
        ;turning RC5 on

        ;the command used for key_a
        call    ClrLCD
        Display KeyA
        call Switch_Lines
        Display KeyLine2

        movlw   B'00100000'
        movwf   PORTC

        btfss	PORTB, 1     ;Wait until signal is sent
        goto	$-1
        btfsc		PORTB,1     ;Wait until key is released
        goto		$-1

        movlw   B'10000000'
        movwf   PORTC

        btfss	PORTB, 1     ;Wait until signal is sent
        goto	$-1
        btfsc		PORTB,1     ;Wait until key is released
        goto		$-1

        movlw   B'10100000'
        movwf   PORTC

        btfss	PORTB, 1     ;Wait until signal is sent
        goto	$-1
        clrf    PORTC
        call    ClrLCD
        goto    main_menu

key_b
        call    ClrLCD
        Display NonSet2
        call Switch_Lines
        Display KeyLine2

key_b_loop
        btfss	PORTA, 0     ;Wait until signal is sent
        goto    $+3
        movlw   B'10100000'
        movwf   PORTC
        btfsc   PORTA, 0
        goto    $+2
        clrf    PORTC
        btfss   PORTB, 1
        goto    key_b_loop
        call    ClrLCD
        goto    main_menu

divide
        clrf    quotient
        goto    divide_loop

divide_loop
        decfsz  sensor_count, f ;decrements the sensor_counter to check if its one
        goto    $+3
        incf    quotient, f ;(rounding the division up)
        goto    $+3
        btfss   sensor_count, 7 ;checks to see if the subtraction caused carry over
        goto    $+2
        goto    divide_end
        incf    quotient, f ; at this point, it's the normal division loop
        decf    sensor_count, f
        goto    divide_loop

divide_end
        return

end

;key_b
        ;turning RC5 on
 ;       movlw   B'10000000'
  ;      movwf   PORTC
;
        ;the command used for key_a
 ;       call    ClrLCD
  ;      Display KeyB
   ;     call Switch_Lines
    ;    Display KeyLine2
;
 ;       btfss	PORTB, 1     ;Wait until signal is sent
  ;      goto	$-1
   ;     clrf    PORTC
    ;    call    ClrLCD
     ;   goto    main_menu

;standby
        ;; set the standby display
        ;call    ClrLCD
        ;Display NonSet1
        ;call Switch_Lines
        ;Display NonSet2

        ;btfss	PORTA, 0     ;Wait until signal is sent
        ;goto	$-1

        ;; set the signal display, now that the signal has been received.
        ;call    ClrLCD
        ;Display Signal
        ;call Switch_Lines
        ;Display KeyLine2

        ;btfss	PORTB, 1     ;Wait until signal is sent
        ;goto	$-1
        ;call    ClrLCD
        ;goto    main_menu
