; This program is intended for AND EK-410V and FX-3000i with Zero Freeze
; 7+2+1 Hardware
; it detects baud rates--300,600,1200,2400,4800,9200
; uses CR+LF as delimeter, pairity any, stop bit-1
;|30|31|32|33|34|35|36|37|38|39|3A|3B|3C|3D|3E|3F |				
;|S | T| ,| +| 0| 0| 0| 0| 0| .| 0| 0|  |  | g| CR|LF|
;|49|  |  |49|40|41|42|43|44.| |45|46|  |47|48|   |				
POINTER 	equ r0 ;RAM pointer at top of RAM
TEMPPTR		equ r1
COUNTER 	equ r2 ;counter
TEMPCOUNTER	equ	r3
TEMP		equ r4
countTX		equ r5 ;counts number of bytes sent by TX eg,
TEMP2		equ r6
errorcount	equ 7
MAX			equ 0Ah; use 10 transistors
MaxErrorCount	equ 255d 
countMAX	equ 0Fh ;for AND [DATA+Cr+Lf]=0E bytes
serialOFFSET	equ 04h;|S | T| ,| +|
serialRAM 	equ 30h 
displayRAM	equ	40h
FLAG		bit 20h
ERRORFLAG	bit	21h
BAUDFOUND	bit	22h
CR_FLAG		bit	23h
decimalFlag	bit 24h

org 0000h
	jmp main
timer0:
org 000Bh
	acall displayfxn
	reti
serial:						   
org 0023H
	jb ti,nothingtodo
	call receiveRoutine;updateRAM
	nothingtodo:reti
receiveRoutine: 
	push psw
	push 0e0h ;push A
	setb rs0 ;BANK-3
	setb rs1 ;BANK-3
	;------fetch the received byte-------
	clr ri
	mov a,sbuf
	anl	a,#7fh
	mov errorcount,#00h
	;------------find Marker------------------
		jb	FLAG,FlagIsSetAlready
			jb CR_FLAG,TestForLF
		acall DelimeterTest_CR;FLAG is set in the routine
			jmp exit0
			TestForLF:
		acall DelimeterTest_LF
			jmp exit0
		FlagIsSetAlready:		
			acall PushInRAM
;------entred in RAM--------exit serial----------
		cjne COUNTER,#countMAX,exit0
			clr	FLAG
			acall	TransferDigits
			acall	SignRoutine
			acall	StabilityRoutine
			acall	UnitsRoutine
			acall	ZerosElimination
	exit0: 	pop 0E0h
			pop PSW
ret;receiveRoutine
							DelimeterTest_CR:
									cjne a,#0Dh,notCarriageReturn
										setb	CR_FLAG; CR found
									notCarriageReturn:
									RET
							DelimeterTest_LF:
									clr CR_FLAG;immidiate after CR
									cjne a,#0Ah,notLineFeed
										acall DelimeterRoutine
									RET
									notLineFeed:
							ret;DelimeterTest
							DelimeterRoutine:
									setb FLAG
									setb BAUDFOUND
									mov errorcount,#00h;avoids calling CAS
									mov COUNTER,#00h
									mov POINTER,#serialRAM							
							ret;DelimeterRoutine

							PushInRAM:
										mov @POINTER,a
										inc	POINTER
										inc COUNTER 
							ret;DataFound

							TransferDigits:
									mov	COUNTER,#00h
									mov a,#serialRAM
									add a,#serialOFFSET; actual data starts after [ST,+]
									mov POINTER,A
									mov TEMPCOUNTER,#00h				  ;
									mov TEMPPTR,#displayRAM				  ;
									RepeatedMapping:						  ;
									 	mov a,@POINTER						  ;
											cjne a,#'.',notdecimal			  ;
												call decimalroutine			  ;
												setb decimalFlag
												jmp nextdigit				  ;
											notdecimal:						  ;
									 			movc a,@a+dptr				  ;
												mov	@TEMPPTR,A				  ;
										nextdigit:							  ;
										inc	COUNTER							  ;
										inc	POINTER							  ;
										inc TEMPPTR							  ;
										cjne counter,#08h,repeatedMapping;[00000.00]
										jb decimalFlag,shiftingNotReq
											acall shift
											mov a,3Bh
											movc a,@a+dptr
											mov 46h,a
											shiftingNotReq:
											clr decimalFlag
									 		mov counter,#00h				  ;
									 		mov POINTER,#serialRAM			  ;
							ret;TransferDigits	
							decimalroutine:
										dec TEMPPTR
										mov	a,@TEMPPTR
										anl	a,#0fbh
										mov	@TEMPPTR,a
							ret;decimalroutine

							SignRoutine:; S/U/Q/O and sign at 49h RAM
									mov a,33h			;33h stores +/-
									orl 49h,#20h
								cjne a,#'-',updateSign
									anl 49h,#0DFh
							updateSign:
							ret;
							StabilityRoutine:
								mov	a,30h
									anl 49h,#7Fh;Stable
									orl 49h,#08h
								cjne a,#'U',Stable; S=Q; U=unstable
									orl 49h,#80h ;NOT stble
									anl 49h,#0F7h
								Stable:	
							ret;SignStability

							UnitsRoutine:
							mov a,3Eh
								gram:cjne a,#'g',PCS
										mov 47h,#0ffh
										mov 48h,#26h
								mov a,3ah; decimal used in Shift_or_Not routine
								acall Shift_or_Not
								ret;gram

								PCS:cjne a,#'C',PER
										mov 47h,#085h
										mov 48h,#27h
								ret
								PER:cjne a,#'%',DecimalOunce
									mov 47h,#085h
									mov 48h,#0D7h
								;mov a,**h; decimal used in Shift_or_Not routine
								;acall Shift_or_Not
									ret
								DecimalOunce:cjne a,#'z',DecimalPound
									mov 47h,#56h;o
									mov 48h,#35h;z
								mov a,38h; decimal used in Shift_or_Not routine
								acall Shift_or_Not
								mov a,3ah
								acall Shift_or_Not
									ret
								DecimalPound:cjne a,#'b',OunceTroy
									mov	47h,#67h	;L
									mov 48h,#46h;b
								mov a,37h; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
								OunceTroy:cjne a,#'t',Momme		
											mov a,3Dh			;**** A=3Dh
											cjne a,#'z',Carat
									mov 47h,#56h;o
									mov 48h,#35h;z
								mov a,38h; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
								Carat:cjne a,#'c',PennyWeight	;**** A=3Dh
									mov 47h,#027h;C
									mov 48h,#47h ;t
								mov a,3ah; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
								Momme:cjne a,#'m',Grain
									mov 47h,#96h;m
									mov 48h,#56h;oh
								mov a,39h; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
								PennyWeight:;conditions for 't' aready checked
									mov 47h,#054h;d		 		;****A=3Dh
									mov 48h,#04dh;w
								mov a,3ah; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
						Grain:cjne a,#'N',Tael
							mov 47h,#26h  ;G
							mov 48h,#0D6h ;n
						mov a,3ah
						cjne a,#'.',notGNdot
							ret;
						notGNdot:
						mov a,46h
						anl	a,#0fbh
						mov 46h,a
						acall Shift
						acall Insert
						ret
								Tael:cjne a,#'l',mes
									mov 47h,#47h
									mov 48h,#67h
								mov a,39h; decimal used in Shift_or_Not routine
								acall Shift_or_Not
									ret
								mes:cjne a,#'s',MLT
									mov 47h,#96h
									mov 48h,#07h
								mov a,39h
								acall shift_or_Not
								ret;mes
								MLT:cjne a,#'T',none
									mov 47h,#96h
									mov 48h,#67h
								mov a,3ah
								acall shift_or_Not
								ret;mes

								ret;MLT
								none:mov 47h,#0ffh
									mov 48h,#0ffh
									ret
							ret;UnitsRoutine

							Shift_or_not:
								cjne a,#'.',goback
								acall Shift
								acall Insert
								goback:ret;Shift_or_not
							Shift:
								mov 40h,41h;shift left
								mov 41h,42h;shift left
								mov 42h,43h;shift left
								mov 43h,44h;shift left
								mov 44h,45h;shift left
								mov 45h,46h;shift left
							ret;Shift_N_Insert
							Insert:
								mov	a,#'0'
								movc a,@a+dptr																															
								mov 46h,a		;Zero Freeze
							ret;Insert
							ZerosElimination:
							mov a,#' '
							movc a,@a+dptr
							mov TEMP,a
							;-------------
							mov a,#'0'
							movc a,@a+dptr
							cjne a,40h,exit_ZerosElimination
							mov 40h,TEMP
							cjne a,41h,exit_ZerosElimination
							mov 41h,TEMP							
							cjne a,42h,exit_ZerosElimination
							mov 42h,TEMP
							cjne a,43h,exit_ZerosElimination
							mov 43h,TEMP
							cjne a,44h,exit_ZerosElimination
							mov 44h,TEMP
							cjne a,45h,exit_ZerosElimination
							mov 45h,TEMP														
							exit_ZerosElimination:
							ret;ZerosElimination
;=============MAIN==============================================
main:
;turn off everything  ;
	mov P0,#0ffh	  ;
	mov P2,#0ffh	  ;
	mov 7h,#00h
	setb P3.6		  ;
	setb P3.7		  ;
;turned off everything;
	mov sp,#5fh ;Stack starts from 0x60
	clr FLAG ;clear flag bit
	clr	ERRORFLAG
	clr BAUDFOUND
	clr	CR_FLAG
	anl pcon,#7fh ;set SMOD=0 ie devide by 32
	orl tmod,#22h ;time-1 mode-2 for serial; timer-0 mode2 for display
	mov th0,#00h ;count 256
	setb tr0
	mov scon,#50h ;serial mode-2, REN=1
	orl ie,#92h ;enable global-0x80 serial-0x10 & T0-0x02 interrupts
	MOV 10h,#displayRAM ;bank-2 pointer	R0
	MOV 18h,#serialRAM ;bank-3 pointer	R0
	call helloAND ;initialize RAM with "HELLO"
	mov countTX,#00h
	mov dptr,#ASCII_HW9
	mov th1,#-3d
	setb tr1
	acall BAUDSEARCH
HERE:	sjmp HERE
BAUDSEARCH:	
	bps9600:mov th1,#-3d
		acall delay
		jb BAUDFOUND, endofmain
	bps4800:mov th1,#-6d
		acall delay
		jb BAUDFOUND, endofmain
	bps2400:mov th1,#-12d
		acall delay
		jb BAUDFOUND, endofmain
	bps1200:mov th1,#-24d
		acall delay
		jb BAUDFOUND, endofmain
	bps6000:mov th1,#-48d
		acall delay
		jb BAUDFOUND, endofmain
	bps300:mov th1,#-96d
		acall delay
		jb BAUDFOUND, endofmain
sjmp	BAUDSEARCH
endofmain: jb BAUDFOUND,endofmain
RET;BAUDSEARCH
;===============Display Digits Bank-2====================
displayfxn:
	push psw
	push 0E0h
	setb RS1 ;Bank-2
	clr RS0 ;Bank-2
	call transistorselect ;transistor(COUNTER)
	mov p0,@POINTER ;pointer of display RAM
	inc COUNTER
	inc POINTER
	cjne counter,#MAX,exitdisplayfxn;DIGITS has  letters + NULL
		mov POINTER,#displayRAM
		mov counter,#00h
		inc 7h
		mov R7,7h
		cjne R7,#MaxErrorCount,NotCallCAS
			clr	FLAG
			clr BAUDFOUND
			call helloAND
			NotCallCAS:
	exitdisplayfxn:
	pop 0E0h
	pop psw
	ret
transistorselect:
	;bit addressable Port3 |0xB7|----|0x0B5|0x0B4|0x0B3|0x0B2|0x0B1|----|
	mov 	p2,#0ffh;turn off T0-T6 large segments
	mov 	p0,#0ffh ;turn off all LEDs
	setb	p3.6	;turn off T7 small segment
	setb 	p3.7 	;turn off T8 small segment
	;	least significant digit
	transistor0: cjne COUNTER,#00h,transistor1
		clr 0A6h ;Seg-1 Turned On CLR P2.6 pin27	Most
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
		clr 0A1h ;Seg-6 Turned On CLR P2.1
		ret
	transistor6: cjne COUNTER,#06h,transistor7
		clr 0A0h ;Seg-7 Turned On CLR P2.0	
		ret
	transistor7: cjne COUNTER,#07h,transistor8
		clr 0B6h ;Seg-8 Turned On CLR P3.6
		ret
	transistor8: cjne COUNTER,#08h,transistor9
		clr 0B7h ;Seg-9 Turned On CLR P3.7		Least
		ret
	transistor9: cjne COUNTER,#09H,testfailed
		clr 0A7h ;Seg-10 Turned On CLR P2.7		Sign/Stability
	testfailed:ret
;================= initialize RAM with HELLO=======================
helloAND:
	PUSH PSW ;save RS0,RS1 ie BANK-x
	CLR RS0 ;bank-0
	CLR RS1 ;bank-0
	MOV POINTER,#displayRAM	;40h
	mov @POINTER,#46h	;40=T1  <-H
	inc POINTER
	mov @POINTER,#085h	;41=T2  <-E
	inc POINTER
	mov @POINTER,#0E5h	;42=T4	<-L
	inc POINTER
	mov @POINTER,#0E5h	;43=T3	<-L
	inc POINTER
	mov @POINTER,#20H	;44=T5	<-O
	inc POINTER
	mov @POINTER,#0FFH	;45=T6 	<-Null 
	inc POINTER
	mov @POINTER,#0FFH	;46=T7 	<-Null	
	inc POINTER
	mov @POINTER,#0FFH	;47=T8 	<-Null	Tiny segment1
	inc POINTER
	mov @POINTER,#0FFH	;48=T9 	<-Null	Tiny segment2
	inc POINTER
	mov @POINTER,#0FFH	;49=T0	<-LED-set
	mov POINTER,#displayRAM
	POP PSW
	RET

;==============Delay====================
delay:
	mov 50h,0ffh
	loop1:mov 51h,0ffh
		loop2:	mov 52h,#3h
		loop3:djnz 52h,loop3
				djnz 51h,loop2
					djnz 50h, loop1
		ret
;==================Lookup Table====================================
digits:DB 24h,7Eh,15h,1Ch,4Eh,8Ch,84h,3Eh,04h,0Ch;0,1,2,. . .9 ACTIVE LOW
transistor:DB 7fh,0fdh,0fbh,0f7h,0efh,0dfh;T1,T2,T3,T4,T5,T6 ACTIVE LOW
;for Small Segments
ASCII_HW9:DB 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh;00-0F
DB			 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh;10-1F
DB			 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0dfh,0ffh,0ffh;20-2F	'-'@2dh
			 ;0	 1	  2   3   4   5   6   7   8   9  
DB			 24h,7Eh,15h,1Ch,4Eh,8Ch,84h,3Eh,04h,0Ch,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh			;30-3F digits
			 ;     A  B	  C	  D		E	F	G	H	I	 J	 K	 L	 M	  N	  O	  
DB			 0ffh,84H,46h,27h,54h,07h,87h,26h,0c4h,0feh,06ch,45h,67h,96h,0D6h,56h;40-4F 41->a-z
			 ;P   Q		R	S	T	U	V	  W		X	Y	Z
DB			 85h,08ch,0D7h,2ch,47h,64h,036h,04dh,0e4h,4ch,35h,0ffh,0ffh,0ffh,0ffh,0ffh;50-5F				
			 ;     a	b	c	d	e	f	g	h	i	j	 k	 l   	m	 n	  o	   p	
DB			 0ffh,84H,46h,27h,54h,07h,87h,26h,0c4h,0feh,06ch,45h,67h,96h,0D6h,56h;60-6F 41->a-z
			 ;p   q		r	s	t	u	v	  w		x	y	z
DB			 85h,08ch,0D7h,2ch,47h,64h,036h,04dh,0e4h,4ch,35h,0ffh,0ffh,0ffh,0ffh,0ffh;70-7F				
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;80-8F
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;90-9F
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;A0-AF
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;B0-BF
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;C0-CF
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;D0-DF
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,;E0-EF
				;0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh;F0-FF
end