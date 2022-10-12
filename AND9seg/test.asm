; AnD for 7+2 display 12Mhz
BAUDNUM 	equ -12d ;for 11.0592MHz xtal
POINTER 	equ r0 ;RAM pointer at top of RAM
TEMPPTR		equ r1
COUNTER 	equ r2 ;counter
TEMPCOUNTER	equ	r3
TEMP		equ r4
MAX 		equ 09h ;| +| 0| 0| 0| 0| 0| .| 0| 0|  |  | g|
serialMAX	equ 0Fh
serialRAM 	equ 30h ;base address of RAM
displayRAM	equ	40h
FLAG		bit 20h
MARKER		equ 0Ah ; Line Feed
org 0000h
	jmp main
timer0:
org 000Bh
	acall displayfxn
	reti
main:
;setb ip.4 ; priority to serial
	anl pcon,#7fh ;set SMOD=0 ie devide by 32
	orl tmod,#22h ;time-1 mode-2 for serial; timer-0 mode2 for display
	mov th0,#00h ;count 256
	setb tr0
	mov th1,#BAUDNUM
	setb tr1
	orl ie,#82h ;enable global-0x80 T0-0x02 interrupts
	mov COUNTER,#00H
wait: sjmp wait
;===============Display Digits Bank-2====================
displayfxn:
	call transistorselect ;transistor(COUNTER)
	inc COUNTER
	inc POINTER
	cjne counter,#MAX,exitdisplayfxn;DIGITS has  letters + NULL
		mov counter,#00h
	exitdisplayfxn:
	ret
transistorselect:
	;bit addressable Port3 |0xB7|----|0x0B5|0x0B4|0x0B3|0x0B2|0x0B1|----|
	orl p2,#0ffh ;forget previous transistor states
	setb p3.7 ;0xB7 ie Transistor #9
	mov p0,#0ffh ;turn off all LEDs
	;	least significant digit
	transistor0: cjne COUNTER,#00h,transistor1
		clr 0A6h ;Seg-1 Turned On CLR P2.6	 least
		MOV P0,#7EH
		ret
	transistor1: cjne COUNTER,#01h,transistor2
		clr 0A5h ;Seg-2 Turned On CLR P2.5
		MOV P0,#15H
		ret
	transistor2: cjne COUNTER,#02h,transistor3
		clr 0A4h ;Seg-3 Turned On CLR P2.4
		MOV P0,#1CH	
		ret
	transistor3: cjne COUNTER,#03h,transistor4
		clr 0A3h ;Seg-4 Turned On CLR P2.3
		MOV P0,#4EH
		
		ret
	transistor4: cjne COUNTER,#04h,transistor5
		clr 0A2H ;Seg-5 Turned On CLR P2.2
		MOV P0,#8CH

		ret
	transistor5: cjne COUNTER,#05h,transistor6
		clr 0A1h ;Seg-0 Turned On CLR P2.1	
		MOV P0,#84H

		ret
	transistor6: cjne COUNTER,#06h,transistor7
		clr 0A0h ;Seg-0 Turned On CLR P2.0	
		MOV P0,#3EH

		ret
	transistor7: cjne COUNTER,#07h,transistor8
		clr 0B6h ;Seg-0 Turned On CLR P2.0	
		MOV P0,#04H

		ret
	transistor8: cjne COUNTER,#08h,testfailed
		clr 0B7h ;Seg-0 Turned On CLR P3.7	 most
		MOV P0,#0CH

	testfailed:ret
end