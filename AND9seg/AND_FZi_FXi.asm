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
serial:						   
org 0023H
	call updateRAM; OK
	reti
updateRAM: 
	push psw
	push 0e0h
	setb rs0 ;BANK-3
	setb rs1 ;BANK-3
	;------fetch the received byte-------
	clr ri
	mov a,sbuf
	anl a,#7fh ;ignore MSB, since MSB is pairity;7bit-UART
	;------------------------------
	cjne a,#MARKER,PUSHinRAM 
		setb FLAG
		mov COUNTER,#00h
		mov POINTER,#serialRAM
		jmp exit0
		;----------Fill the RAM-------------
		;|30|31|32|33|34|35|36|37|38|39|3A|3B|3C|3D|3E|3F |				
		;|S | T| ,| +| 0| 0| 0| 0| 0| .| 0| 0|  |  | g| CR|
		PUSHinRAM:
		jnb FLAG,exit0
			mov @POINTER,a ;PUSHED
			inc POINTER
			inc COUNTER
		;------entred in RAM--------exit serial----------
		cjne COUNTER,#serialMAX,exit0
		;-----------all entries has been made in RAM--------------	
				clr		FLAG
				mov dptr,#digits			
				acall common
				mov TEMP,3Eh	;last letter g/C/%
				mov a,3Dh		;second last letter
				add a,TEMP
				mov TEMP,a

				cjne TEMP,#87h, notgrams;ASCII '\b'+'g' = 0x87
					call gram
					jmp exit0
			notgrams:
					cjne TEMP,#93h,notPCS ;pieces ASCII 'P'+'C'=93
					call PCS
					jmp exit0
			notPCS:
					cjne TEMP,#45h,notPERCENT
					call PERCENT
					jmp exit0
			notPERCENT:
					cjne	TEMP,#0E9h,notOZ
					call OZ
					jmp exit0
			notOZ:
					cjne TEMP,#0CEh,notLB
					call LB
					jmp exit0
			notLB:
					cjne TEMP,#0EEh,notZT
					call OZ	;ZT is same as OZ
					jmp exit0
			notZT:
					cjne TEMP,#0D7h,notCT
					call gram;CT is same as gram
					jmp exit0
			notCT:
					cjne TEMP,#0dch,notOM
					call OZ;OM is same as OZ
					jmp exit0
			notOM:
					cjne TEMP,#0ebh,notWT
					call gram ;WT is same as gram
					jmp exit0
			notWT:
					cjne TEMP,#95h,notGN 
					call GN
					jmp exit0
			notGN:
					cjne TEMP,#0E0h,notTL 
					call LB;TL is same as LB
					jmp exit0
			notTL:
			exit0: 	pop 0E0h
					pop PSW
					ret
	common:  
;|+ |36|37|38.|3A|3B|
;|45|44|43|42 |41|40|
				;-----Sign digit-----------
				mov a,33h
				;mov 45h,#0ffh
				cjne a,#'-',positive
				;mov 45h,#0fbH
				positive:;do nothing
					MOV 	TEMPPTR,#34h
					MOV 	TEMPCOUNTER,#08h
		;Map ASCII digits to display digits
		mapping:	mov 	a,@TEMPPTR
					clr		C
					subb 	a,#'0'
					movc 	a,@a+dptr ;dptr is defined in main
					mov 	@TEMPPTR,a
					inc 	TEMPPTR
					djnz	TEMPCOUNTER,mapping
 	RET;common

				gram:
						mov		47h,#26h 	;Gra
						mov		48h,#0F2h	;m
						mov 	46h,#24h	;forced zero
					mov		A,39h
					;   |  |0 |0 |0 |0 |.|0 |0 |0 |
					;|+ |34|35|36|37|38|.|3A|3B|
					;    |  |40|41|42 |43|44|45|46|
					cjne	A,#'.',DECIMALPLACE3
						mov		45h,3Bh
						mov 	44h,3Ah
						mov		43h,38h
						anl		43h,#0FBh	;39 is decimal;P0.2 -> h
						mov		42h,37h
						mov 	41h,36h		;2nd 7-seg from left
						mov 	40h,35h
						JMP		EXITgram
					DECIMALPLACE3:
						mov		45h,3Ah
						mov 	44h,39h
						anl		44h,#0FBh
						mov		43h,37h
						mov		42h,36h
						mov 	41h,35h		;2nd 7-seg from left
						mov 	40h,34h
					EXITgram:	
						mov TEMP,#04h 	;mask 48h,47h,46h,45h if required
						mov TEMPPTR,#40h
						call maskzeros
						ret;gram			
				PCS:
					mov		47h,#0A1h 	;P
					mov		48h,#27h	;C
					mov 	46h,3Bh
					mov		45h,3Ah
					mov 	44h,38h
					mov		43h,37h
					mov		42h,36h
					mov 	41h,35h		;2nd 7-seg from left
					mov 	40h,34h
					mov TEMP,#06h 	;mask 48h,47h,46h,45h if required
					mov TEMPPTR,#40h
					call maskzeros
				ret;PCS	
				PERCENT:
					mov		47h,#0A1h 	;P
					mov		48h,#0F3h	;r
					mov 	46h,3Bh
					mov		45h,3Ah
					anl		45h,#0FBh
					mov 	44h,38h
					mov		43h,37h
					mov		42h,36h
					mov 	41h,35h		;2nd 7-seg from left
					mov 	40h,34h
					mov TEMP,#05h 	;mask 48h,47h,46h,45h if required
					mov TEMPPTR,#40h
					call maskzeros
				ret;PERCENT
				OZ:
					mov		47h,#26h 	;o
					mov		48h,#0F2h	;z
					mov 	46h,3Bh
					mov		45h,3Ah
					mov 	44h,38h
					mov		43h,37h
					anl		43h,#0FBh	;39 is decimal;P0.2 -> h
					mov		42h,36h
					mov 	41h,35h		;2nd 7-seg from left
					mov 	40h,34h
					mov TEMP,#03h 	;mask 48h,47h,46h,45h if required
					mov TEMPPTR,#40h
					call maskzeros
				ret;OZ
				LB:
					mov		47h,#26h 	;o
					mov		48h,#0F2h	;z
					mov 	46h,3Bh
					mov		45h,3Ah
					mov 	44h,38h
					mov		43h,37h
					mov		42h,36h
					anl		42h,#0FBh	;39 is decimal;P0.2 -> h
					mov 	41h,35h		;2nd 7-seg from left
					mov 	40h,34h
					mov TEMP,#02h 	;mask 48h,47h,46h,45h if required
					mov TEMPPTR,#40h
					call maskzeros
				ret;LB
				GN:
					mov 	44h,36H		;2nd 7-seg from left
					mov 	43h,37H		;3rd
					mov 	42h,38H		;4th
					mov 	41h,39h	 	;5th
					anl 	41h,#7Fh	;3Ah is decimal
					mov 	40h,3Bh	 	;6th
					mov TEMP,#03h 		;mask 44h,43h,42h,41h if required
					mov TEMPPTR,#44h
					call maskzeros

						maskzeros:
							mov a,@TEMPPTR
							cjne a,#24h, quitmasking;otherwise mask
							mov @TEMPPTR,#0ffh
							inc	TEMPPTR 
							djnz TEMP,maskzeros
						quitmasking:
						ret;maskzeros
;=============MAIN==============================================
main:
;setb ip.4 ; priority to serial
	mov sp,#5fh ;Stack starts from 0x60
	clr FLAG ;clear flag bit
	anl pcon,#7fh ;set SMOD=0 ie devide by 32
	orl tmod,#22h ;time-1 mode-2 for serial; timer-0 mode2 for display
	mov th0,#00h ;count 256
	setb tr0
	mov th1,#BAUDNUM
	setb tr1
	mov scon,#50h ;serial mode-2, REN=1
	orl ie,#92h ;enable global-0x80 serial-0x10 & T0-0x02 interrupts
	MOV 10h,#displayRAM ;bank-2 pointer	R0
	MOV 18h,#serialRAM ;bank-3 pointer	R0
	call helloworld ;initialize RAM with "HELLO"
	mov dptr,#digits
wait: sjmp wait
;===============Display Digits Bank-2====================
displayfxn:
	push psw
	setb RS1 ;Bank-2
	clr RS0 ;Bank-2
	call transistorselect ;transistor(COUNTER)
	mov p0,@POINTER ;pointer of display RAM
	inc COUNTER
	inc POINTER
	cjne counter,#MAX,exitdisplayfxn;DIGITS has  letters + NULL
		mov POINTER,#displayRAM
		mov counter,#00h
	exitdisplayfxn:
	pop psw
	ret
transistorselect:
	;bit addressable Port3 |0xB7|----|0x0B5|0x0B4|0x0B3|0x0B2|0x0B1|----|
	orl 	p2,#0ffh;turn off T0-T6 large segments
	setb	p3.6	;turn off T7 small segment
	setb 	p3.7 	;turn off T8 small segment
	mov p0,#0ffh ;turn off all LEDs
	;	least significant digit
	transistor0: cjne COUNTER,#00h,transistor1
		clr 0A6h ;Seg-1 Turned On CLR P2.6		Most
		ret
	transistor1: cjne COUNTER,#01h,transistor2
		clr 0A5h ;Seg-2 Turned On CLR P2.5
		ret
	transistor2: cjne COUNTER,#02h,transistor3
		clr 0A4h ;Seg-3 Turned On CLR P2.4
		ret
	transistor3: cjne COUNTER,#03h,transistor4
		clr 0A3h ;Seg-4 Turned On CLR P2.3
		ret
	transistor4: cjne COUNTER,#04h,transistor5
		clr 0A2h ;Seg-5 Turned On CLR P2.2
		ret
	transistor5: cjne COUNTER,#05h,transistor6
		clr 0A1h ;Seg-0 Turned On CLR P2.1
		ret
	transistor6: cjne COUNTER,#06h,transistor7
		clr 0A0h ;Seg-0 Turned On CLR P2.0	
		ret
	transistor7: cjne COUNTER,#07h,transistor8
		clr 0B6h ;Seg-0 Turned On CLR P3.6
		ret
	transistor8: cjne COUNTER,#08h,testfailed
		clr 0B7h ;Seg-0 Turned On CLR P3.7		Least
	testfailed:ret
;================= initialize RAM with HELLO=======================
helloworld:
	PUSH PSW ;save RS0,RS1 ie BANK-x
	CLR RS0 ;bank-0
	CLR RS1 ;bank-0
	MOV POINTER,#displayRAM	;40h
	mov @POINTER,#46h	;T1 =@48h <-H
	inc POINTER
	mov @POINTER,#85h	;T2c=@47h <-E
	inc POINTER
	mov @POINTER,#0E5h	;T4=@45h <-L
	inc POINTER
	mov @POINTER,#0E5h	;T3=@46h <-L
	inc POINTER
	mov @POINTER,#20h	;T5=@44h <- O. New format
	inc POINTER
	mov @POINTER,#0FFH	;T9=@40h <-Null Tiny segment1
	inc POINTER
	mov @POINTER,#0FFH	;T8=@41h <-Null	Tiny segment2
	inc POINTER
	mov @POINTER,#0FFH	;T7=@42h <-Null
	inc POINTER
	mov @POINTER,#0FFH	;T6=@43h <-Null
	mov POINTER,#displayRAM
	POP PSW
	RET
;==================Lookup Table====================================
digits:DB 24h,7Eh,15h,1Ch,4Eh,8Ch,84h,3Eh,04h,0Ch;0,1,2,. . .9 ACTIVE LOW
transistor:DB 7fh,0fdh,0fbh,0f7h,0efh,0dfh;T1,T2,T3,T4,T5,T6 ACTIVE LOW
end