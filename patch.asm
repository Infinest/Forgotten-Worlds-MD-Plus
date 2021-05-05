; Build params: ------------------------------------------------------------------------------
CHEAT set 0
; Constants: ---------------------------------------------------------------------------------
	MD_PLUS_OVERLAY_PORT:			equ $0003F7FA
	MD_PLUS_CMD_PORT:				equ $0003F7FE
	MD_PLUS_RESPONSE_PORT:			equ $0003F7FC

	RESET_VECTOR:					equ $00000004
	ORIGINAL_RESET_VECTOR:			equ $00000200
	SOUND_DRIVER_PAUSE_MUSIC:		equ	$0000070C
	SOUND_DRIVER_RESUME_MUSIC:		equ	$00000742
	SOUND_DRIVER_PLAY_SFX_OR_MUSIC: equ $0001335E
	CONTROLLER_VALUE_TABLE:			equ $00018456
	TRACK_INDEX_TABLE:				equ $00018672

	RAM_LAST_PLAYED_TRACK:			equ $FFFFFFF0

	TRACK_INDEX_TABLE_LENGTH:		equ $00000010
	
; Overrides: ---------------------------------------------------------------------------------
	if	CHEAT

	org $001162							; Always get bonus points and post level cutscene
	nop
	nop
	nop

	org $010C1A							; Infinite Energy
	dc.w $6002

	endif

	org RESET_VECTOR
	dc.l	RESET_DETOUR

	org CONTROLLER_VALUE_TABLE+$7
	dc.b $10							; 6-button pad compatibility fix

	org SOUND_DRIVER_PAUSE_MUSIC+$4
	jsr		SOUND_DRIVER_PAUSE_DETOUR
	nop

	org	SOUND_DRIVER_RESUME_MUSIC
	jsr		SOUND_DRIVER_RESUME_DETOUR
	nop

	org SOUND_DRIVER_PLAY_SFX_OR_MUSIC
	jsr		SOUND_DRIVER_PLAY_DETOUR

	org $1901C
	jmp END_CUTSCENE_DETOUR

; Detours: -----------------------------------------------------------------------------------
	org $1A070

RESET_DETOUR
	move	#$1300,D1
	jsr		WRITE_MD_PLUS_FUNCTION
	jmp		ORIGINAL_RESET_VECTOR

SOUND_DRIVER_PAUSE_DETOUR
	move.w	#$1300,D1
	jsr		WRITE_MD_PLUS_FUNCTION
	move.b	#$80,($00A01C08)				; Original game code
	rts

SOUND_DRIVER_RESUME_DETOUR
	move.w	#$1400,D1
	jsr		WRITE_MD_PLUS_FUNCTION
	bclr	#$0,($FFFF0625)					; Original game code
	rts

SOUND_DRIVER_PLAY_DETOUR
	movem.l	D1/A0,-(A7)						; Push D1 and A0 onto stack
	movea.l	#TRACK_INDEX_TABLE,A0
	move.w	#$FF,D1
LOOP										; This loop walks through the games track pointer table
	addi.b	#$1,D1							; to convert the given pointer into the track index number
	cmpi.b	#TRACK_INDEX_TABLE_LENGTH,D1
	bhi		NOT_MUSIC						; If we looped long enough to reach the end, the pointer is not for a music track
	cmp.b	(A0,D1),D0
	bne		LOOP
	addi.b	#$1,D1
	move.b	D1,(RAM_LAST_PLAYED_TRACK)		; Write track to RAM value containing last played track
	ori.w	#$1200,D1
	jsr		WRITE_MD_PLUS_FUNCTION
	move.b	#$C1,D0
	bra		NOT_FADE_COMMAND
NOT_MUSIC
	cmpi.b	#$C1,D0							; Check for special stop command
	bne		NOT_STOP_COMMAND
	move.w	#$1300,D1
	jsr		WRITE_MD_PLUS_FUNCTION
NOT_STOP_COMMAND
	cmpi.b	#$C0,D0							; Check for special fade out command
	bne		NOT_FADE_COMMAND
	move.w	#$1315,D1
	jsr		WRITE_MD_PLUS_FUNCTION
NOT_FADE_COMMAND
	movem.l (A7)+,D1/A0						; Retrieve old values for D1 and A0 from stack
	movea.l	A6,A5							; Original game code
	addq.w	#$1,A6
	move.b	(A6)+,(A5)+
	rts

END_CUTSCENE_DETOUR							; This detour ensures that the bonus scenes after a level can only automatically end after level complete track has finished playing
	cmpi.b	#$D,(RAM_LAST_PLAYED_TRACK)		; Check if the last played track is the level complete track
	bne		NOT_LEVEL_END_CUTSCENE
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)	; Open interface
	move.w  #$1600,(MD_PLUS_CMD_PORT)		; Check if cd audio is still playing
	move.b	(MD_PLUS_RESPONSE_PORT),D0
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)	; Close interface
	cmpi.b	#$1,D0
	bne		DO_NOT_RESTART_TIMER
	jmp		$1900C							; If the track is no still playing we start the timer for automatically ending the cutscene over
DO_NOT_RESTART_TIMER
	move.b	#$0,(RAM_LAST_PLAYED_TRACK)		; The level complete track has finished playing, set last played track to zero
NOT_LEVEL_END_CUTSCENE
	bset	#$7,($FF3366)					; Original game code
	move	#$2000,SR
	rts

; Helper Functions: --------------------------------------------------------------------------

WRITE_MD_PLUS_FUNCTION:
	move.w  #$CD54,(MD_PLUS_OVERLAY_PORT)	; Open interface
	move.w  D1,(MD_PLUS_CMD_PORT)			; Send command to interface
	move.w  #$0000,(MD_PLUS_OVERLAY_PORT)	; Close interface
	rts
