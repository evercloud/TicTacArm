@ 	Author: Claudio Scamporlino
@	Università degli Studi di Catania
@	Corso di Architettura degli Elaboratori
@	Prof. Nino Cauli
        
	.syntax unified         @ modern syntax


@ Definition of GPIO addresses:
		.equ    GPIO,0x3f200000			@ base address: other values are offsets!
		.equ	GPIOSEL0, 0x0 			@ selects pins 0-9 function - 3 bits/pin (e.g. 000=input 001=output)
		.equ 	GPIOSEL1, 0x4 			@ -> same for pins 10-19 
		.equ	GPIOSEL2, 0x8 			@ -> same for pins 20-29
		.equ	GPSET0, 0x1C 			@ sets output pin values - 1 bit per pin -> 0-31
		.equ	GPCLR0, 0x28 			@ resets output pin values - 1 bit per pin -> 0-31
		.equ	GPLEV0, 0x34 			@ read (input?) pin values - 1bit per pin -> 0-31

@ GPIO fields
		.equ	INPUT1, 0x4000			@ pin 8  GPIO14	Button1
		.equ	INPUT2, 0x20000 		@ pin 11 GPIO17	Button2
	
		.equ	M00, 	0x40000 		@ pin 12 GPIO18
		.equ	M01,	0x400000		@ pin 15 GPIO22
		.equ	M02,	0x1000000		@ pin 18 GPIO24
		.equ	M03,	0x200			@ pin 21 GPIO09
		.equ	M04,	0x800			@ pin 23 GPIO11
		.equ	M05, 	0x40 			@ pin 31 GPIO06
		.equ	M06,	0x2000			@ pin 33 GPIO13
		.equ	M07,	0x10000			@ pin 36 GPIO16
		.equ	M08,	0x100000		@ pin 38 GPIO20
	
		.equ	M10,	0x8000000		@ pin 13 GPIO27
		.equ	M11,	0x800000		@ pin 16 GPIO23
		.equ	M12,	0x400			@ pin 19 GPIO10
		.equ	M13,	0x2000000		@ pin 22 GPIO25
		.equ	M14, 	0x20 			@ pin 29 GPIO05
		.equ	M15,	0x1000			@ pin 32 GPIO12
		.equ	M16,	0x80000			@ pin 35 GPIO19
		.equ	M17,	0x4000000		@ pin 37 GPIO26
		.equ	M18,	0x200000		@ pin 40 GPIO21

		.equ	P0, 	0x1552A40		@ all p0 pins #0b1010101010010101001000000
		.equ	P1, 	0xEA81420		@ all p1 pins #0b1110101010000001010000100000
		
@ Others parameters
		.equ	LIMIT,	0x1FF			@ spaces limit 111111111
		.equ	BOUNDS,	0b1000000000	@ out of bounds move
		.equ	V1,	0b111000000			@ victory 1 
		.equ	V2,	0b000111000			@ victory 2
		.equ	V3,	0b000000111			@ victory 3
		.equ	V4,	0b100100100			@ victory 4
		.equ	V5,	0b010010010			@ victory 5
		.equ	V6,	0b001001001			@ victory 6
		.equ	V7,	0b100010001			@ victory 7 - cannot use immediate value (invalid constant after fixup error)
		.equ	V8,	0b001010100			@ victory 8

		.equ	DELAY,	500000		@ 5*10^7 empiric value from playtesting, reduce by 100x on bare metal
		.equ	BLINK,	2000000		@ 2*10^8 same here: reduce by 100x on bare metal

		.global main

						
			.data						@ setup some variables in memory
P0MOVES:	.word	0					@ p0 moves
P1MOVES:	.word	0					@ p1 moves 
ALLMOVES:	.word	0					@ all moves, to save some load and store (= p0 OR p1)

main:						

	
		@ Set GPIO 05,06,09,10,11,12,13,16,18,19,20,21,22,23,24,25,26,27 as outputs 
		@ Set GPIO 14,17 as input
		ldr		r0, =#0x8048000		@ set GPIO 5,6,9  001000000001001000000000000000
		str		r0, [r5, #GPIOSEL0]	@ update pins status
		ldr		r0, =#0x9040249		@ set GPIO 10,11,12,13,16,18,19 (and confirm 14,17 as input) 001001000001000000001001001001
		str		r0, [r5, #GPIOSEL1]	@ update pins status
		ldr		r0, =#0x249249		@ set GPIO 20,21,22,23,24,25,26,27 001001001001001001001001
		str		r0, [r5, #GPIOSEL2]	@ update pins status       
		
		
		@ REGISTERS SUMMARY
		@ r6 -> current player: 0 for player0 and 1 for player1
		@ r7 -> currently selected LED status (on/off)
		@ r8 -> current move: 0b1 for first square
		@ r9 -> input edge: 0 when not clicked, 1 when holding button
		@ r10 -> track all enabled gpios
		@ r11 -> currently selected LED
		@ r12 -> timer cycles
		
		
		mov		r6, #0				@ set P0 as first player just in the first match

newGame:		
		ldr		r0, =#P1|P0
		str		r0, [r5, #GPCLR0]	@ turn off all gpios
		mov 	r0, #0
		ldr		r1, =P0MOVES		@ load player 0 moves memory address
		str		r0, [r1]			@ reset player 0 moves
		str		r0, [r1, #4]		@ (P0MOVES + offset) reset player 1 moves
		str		r0, [r1, #8]		@ (P0MOVES + offset) reset all moves
		mov		r10, #0				@ reset enabled gpios
		
newTurn:	
		mov 	r7, #0				@ new LED is disabled as default on new turn
		ldr		r0, =ALLMOVES		@ load all moves moves memory address
		ldr 	r1, [r0]			@ load all moves
		ldr		r0, =#LIMIT		
		cmp		r0, r1				@ check if there is any available moves left. If equal, end match with draw
		beq		blinkEnd	
		eor		r6, r6, #1			@ use xor to switch last player here to prevent benefitting last winner
	
resetTurn: 	
		mov		r8, #1				@ set current move to 000000001
		
checkIfTaken:
		ldr		r0, =ALLMOVES		@ load all moves memory address
		ldr		r1, [r0]			@ get all moves
		and		r0, r8, r1			@ AND condition between actual move and free spaces		
		cmp		r0, r8				@ compare or result with free spaces
		beq		goToNextSpace		@ if result is equal to SPACES the place was already taken
	
inputLoop: 							@ we get here only if valid move is currently selected
		ldr		r0, [r5, #GPLEV0] 	@ read pin value -> this returns 32 bit 0-31 pins
		and		r1, r0, #INPUT1		@ AND to check if input1 pin is on
		cmp		r1, #INPUT1			@ compare inputs with button 1
		beq		pressedButton1		@ go to button 1 logic
		and		r1, r0, #INPUT2		
		cmp 	r1, #INPUT2			@ if button 1 was not pressed, check for button 2
		beq		pressedButton2		@ go to button 2 logic
		mov		r9, #0				@ if you get here, no button was clicked, so update our edge controller
		@b		delay				@ if no button (or more than one) was pressed, jump to delay system

delay:								@ delay system prevents multiple clicks and handles the LED blinking
		ldr		r12, =#DELAY		@ get the delay value
		
resumeDelay:	
		sub		r12, r12, #1		@ subtract 1... 
		cmp		r12, #0				@ ...until we exit the delay loop
		ble		resetDelay
		b		resumeDelay			@ or keep looping
		
resetDelay:
		eor		r7, r7, #1			@ xor to invert current LED on/off
		cmp		r7, #0				@ if current LED was just turned on...
		bgt		enableMove			@ ...enable it
		b		turnOffLED			@ otherwise turn it off
		
pressedButton1:		
		cmp		r9, #1				@ if we are holding the button...
		beq		inputLoop			@ ...keep looping
		mov		r9, #1				@ otherwise  prevent future button loops before continuing
				
goToNextSpace:
		lsl		r8, r8, #1			@ shift left current selected Move (e.g. from 000000001 to 000000010)
		cmp		r8, #BOUNDS
		beq		resetTurn			@ if we reached an invalid move, reset turn
		b		checkIfTaken		@ otherwise, repeat move validation
		
pressedButton2:	
		cmp		r9, #1				@ same as button1
		beq		inputLoop
		mov		r9, #1

confirmMove:	
		ldr		r0, =ALLMOVES		@ get all moves memory address
		ldr		r1, [r0]			@ get all moves
		orr		r1, r1, r8			@ add new move to taken spaces list
		str		r1, [r0]			@ store all moves
		cmp		r6, #0			
		ldrgt	r1, =P0MOVES		@ if player 0 get ready to load p0 moves
		ldrle	r1, =P1MOVES		@ otherwise get p1 moves address
		ldr		r0, [r1]			@ load moves
		orr		r0, r0, r8			@ add new move to current player's
		str		r0, [r1]			@ store again
		orr		r10, r10, r11		@ add new led to led list
		ldr		r2, =#P1|P0
		str		r2, [r5, #GPCLR0]	@ turn off all gpios
		str		r10, [r5, #GPSET0]

CheckVictory:	
		and		r1, r0, #V1			@ if an AND between moves and a victory combination...
		cmp		r1, #V1				@ ...returns the victory combination itself, we have a match
		beq		blinkEnd			@ in that case, trigger gameover
		and		r1, r0, #V2
		cmp		r1, #V2
		beq		blinkEnd
		and		r1, r0, #V3
		cmp		r1, #V3
		beq		blinkEnd
		and		r1, r0, #V4
		cmp		r1, #V4
		beq		blinkEnd
		and		r1, r0, #V5
		cmp		r1, #V5
		beq		blinkEnd
		and		r1, r0, #V6
		cmp		r1, #V6
		beq		blinkEnd
		and		r1, r0, #V8
		cmp		r1, #V8
		beq		blinkEnd
		ldr		r1, =#V7			@ V7 was too long for immediate value
		and		r0, r0, r1			@ so I first store it in a register
		cmp		r0, r1				@ and then compare
		beq		blinkEnd
		b		newTurn
		
enableMove:	
		cmp		r8, #0b000000001	@ if first square was selected, do not jump
		bne		M1			
		cmp		r6, #0				@ check which player it is and...
		movle	r11, #M10			@ ...pick the correct led pin accordingly
		movgt	r11, #M00		
		b		turnOnLED			@ do not forget to turn on the LED!
M1:		cmp		r8, #0b000000010	@ if second square was selected... and so on
		bne		M2			
		cmp		r6, #0			
		movle	r11, #M11	
		movgt	r11, #M01
		b		turnOnLED
M2:		cmp		r8, #0b000000100
		bne		M3
		cmp		r6, #0
		movle	r11, #M12	
		movgt	r11, #M02
		b		turnOnLED
M3:		cmp		r8, #0b000001000
		bne		M4
		cmp		r6, #0
		movle	r11, #M13	
		movgt	r11, #M03
		b		turnOnLED
M4:		cmp		r8, #0b000010000
		bne		M5
		cmp		r6, #0
		movle	r11, #M14	
		movgt	r11, #M04
		b		turnOnLED
M5:		cmp		r8, #0b000100000
		bne		M6
		cmp		r6, #0
		movle	r11, #M15	
		movgt	r11, #M05
		b		turnOnLED
M6:		cmp		r8, #0b001000000
		bne		M7
		cmp		r6, #0
		movle	r11, #M16	
		movgt	r11, #M06
		b		turnOnLED
M7:		cmp		r8, #0b010000000
		bne		M8
		cmp		r6, #0
		movle	r11, #M17	
		movgt	r11, #M07
		b		turnOnLED
M8:									@ if you got here, hopefully you do not need the last CMP
		cmp		r6, #0
		movle	r11, #M18	
		movgt	r11, #M08
		b		turnOnLED
		
turnOffLED:
		ldr		r0, =#P1|P0
		str		r0, [r5, #GPCLR0]	@ turn off all gpios
		str		r10, [r5, #GPSET0]	@ turn on all saved as enabled gpios
		b		inputLoop
		
turnOnLED:
		ldr		r0, =#P1|P0
		str		r0, [r5, #GPCLR0]	@ turn off all gpios
		str		r10, [r5, #GPSET0]	@ turn on all saved as enabled gpios
		str		r11, [r5, #GPSET0]	@ turn on also the current led
		b		inputLoop

blinkEnd: 							@ game over: all leds flash on/off 5 times. 
		mov		r1, #10				@ on/off counter (5*2)
		mov		r2, #1				@ on/off controller
		
blinkAgain:	
		ldr		r12, =#BLINK		@ get the delay value
		
resumeBlink:	
		sub		r12, r12, #1		
		cmp		r12, #0
		ble		triggerBlink
		b		resumeBlink
		
triggerBlink:
		sub		r1, #1			
		cmp		r1, #0				@ if blinking is over, start a new game
		beq		newGame
		cmp		r2, #1				@ otherwise keep blinking 
		beq		blinkOff		
		b		blinkOn

blinkOff:	
		mov		r2, #0
		ldr		r0, =#P1|P0
		str		r0, [r5, #GPCLR0]	@ turn off all gpios
		b		blinkAgain
		
blinkOn:	
		mov		r2, #1
		str		r10, [r5, #GPSET0]
		str		r11, [r5, #GPSET0]
		b		blinkAgain
	


@ NO end condition. Bye!
