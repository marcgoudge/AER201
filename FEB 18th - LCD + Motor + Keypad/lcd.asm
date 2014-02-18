	#include <p16f877.inc>

	;Declare unbanked variables (at 0x70 and on)
	udata_shr
lcd_tmp	res	1
lcd_d1	res	1
lcd_d2	res	1
com		res	1
dat		res	1

	;Declare constants for pin assignments (LCD on PORTD)
#define	RS 	PORTD,2
#define	E 	PORTD,3

;Delay: ~160us
LCD_DELAY macro
	movlw   0xFF
	movwf   lcd_d1
	decfsz  lcd_d1,f
	goto    $-1
	endm


	code 	0x100
	global InitLCD, WR_INS, WR_DATA, ClrLCD, Switch_Lines		;Only these functions are visible to other asm files.
    ;***********************************
InitLCD
	bcf STATUS,RP0
	bsf E     ;E default high

	;Wait for LCD POR to finish (~15ms)
	call lcdLongDelay
	call lcdLongDelay
	call lcdLongDelay

	;Ensure 8-bit mode first (no way to immediately guarantee 4-bit mode)
	; -> Send b'0011' 3 times
	movlw	b'00110011'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay
	movlw	b'00110010'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay

	; 4 bits, 2 lines, 5x7 dots
	movlw	b'00101000'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay

	; display on/off
	movlw	b'00001100'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay

	; Entry mode
	movlw	b'00000110'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay

	; Clear ram
	movlw	b'00000001'
	call	WR_INS
	call lcdLongDelay
	call lcdLongDelay
	return
    ;************************************

    ;ClrLCD: Clear the LCD display
ClrLCD
	movlw	B'00000001'
	call	WR_INS
    return

    ;****************************************
    ; Write command to LCD - Input : W , output : -
    ;****************************************
WR_INS
	bcf		RS				;clear RS
	movwf	com				;W --> com
	andlw	0xF0			;mask 4 bits MSB w = X0
	movwf	PORTD			;Send 4 bits MSB
	bsf		E				;
	call	lcdLongDelay	;__    __
	bcf		E				;  |__|
	swapf	com,w
	andlw	0xF0			;1111 0010
	movwf	PORTD			;send 4 bits LSB
	bsf		E				;
	call	lcdLongDelay	;__    __
	bcf		E				;  |__|
	call	lcdLongDelay
	return

    ;****************************************
    ; Write data to LCD - Input : W , output : -
    ;****************************************
WR_DATA
	bsf		RS
	movwf	dat
	movf	dat,w
	andlw	0xF0
	addlw	4
	movwf	PORTD
	bsf		E				;
	call	lcdLongDelay	;__    __
	bcf		E				;  |__|
	swapf	dat,w
	andlw	0xF0
	addlw	4
	movwf	PORTD
	bsf		E				;
	call	lcdLongDelay	;__    __
	bcf		E				;  |__|
	return

Switch_Lines
		movlw	B'11000000'
		call	WR_INS
		return

lcdLongDelay
    movlw d'20'
    movwf lcd_d2
LLD_LOOP
    LCD_DELAY
    decfsz lcd_d2,f
    goto LLD_LOOP
    return

    end