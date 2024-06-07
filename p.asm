; Rule of the thumb
; REP_GRID is your friend
; Whenever you want to screw with grid use dupGrid
; Want to persist something? use grid 

.MODEL SMALL
.STACK 100H
; Structures
Box STRUCT
  xStart dw 0
  xEnd dw 0
  yStart dw 0
  yEnd dw 0
  candy dw 0
  disabled dw 0
Box ENDS
.DATA
  ; Data
  x dw 0 ; X-cordinate (used for printing graphics)
  y dw 0 ; Y-cordinate (used for printing graphics)
  pageNum dw 0 ; Page number
  playerName db 10 DUP('$') ; Player name array
  grid Box 49 DUP(<>)
  dupGrid Box 49 DUP(<>)
  playerScoreLevelOne dw 0
  movesLeft dw 15
  combosFound db 0
  levelOneCurrScore dw 0
  levelTwoCurrScore dw 0
  levelThreeCurrScore dw 0
  levelScore dw 0
  ; Prompts
  gameName db 'Candy Crush', "$" 
  getNamePrompt db 'Please enter your name: ', '$' 
  welcomePrompt db 'Welcome ', '$' 
  pressKeyPrompt db 'Please press any key to continue', '$'
  gameRulesPrompt db 'Game Rules', "$"
  levelOnePrompt db 'Level One', "$"
  levelTwoPrompt db 'Level Two', "$"
  levelThreePrompt db 'Level Three', "$"
  playerNamePrompt db 'Player Name', "$"
  requiredScorePrompt db 'Score Needed', "$"
  currScorePrompt db 'Your Score', "$"
  movesLeftPrompt db 'Moves Left', "$"
  levelOneScore db '20', "$"
  ; Rules of the game
  ruleOne db 'Score is awarded when candies are crushed', "$"
  ruleTwo db 'The score depends on the type of candy you crush', "$"
  ruleThree db 'All candies of same shape and size bear the same score', "$"
  ruleFour db 'The score is dependent on the size of the combo', "$"
  ruleFive db 'A total of 15 moves are allowed in each level', "$"
  ruleSix db 'You must score more than the threshold score to pass the level', "$"
  ruleSeven db 'Use mouse to swap candies', "$"
  ruleEight db 'You cannot swap candies that are not adjacent to eachother', "$"
  ; Macros
  copy dw 0
  xStartCopy dw 0
  xEndCopy dw 0
  yStartCopy dw 0
  yEndCopy dw 0
  foundPos dw 0
  countPos dw 0
  isModZero dw 0
  rem db 0
  quo db 0
  county db 0
.CODE

  ; Macros
  GET_MOD MACRO num, dom
    PUSH AX
    PUSH BX
    PUSH DX

    MOV DX, 0
    MOV AX, num
    MOV BX, dom
    DIV BX

    .IF(DX==0)
      MOV isModZero, 1
    .ELSE
      MOV isModZero, 0
    .ENDIF

    POP DX
    POP BX
    POP AX
  ENDM 

  MULTI_DIGIT_OUTPUT MACRO value
    LOCAL output, output2, print, exit
    output:
      MOV AX, value

      output2:
        CMP AX,0
          JE PRINT
        MOV BL,10
        DIV BL
        MOV rem, AH
        MOV quo, AL
        MOV CL, rem
        MOV CH, 0
        ADD CL, 48
        PUSH CX
        MOV AL, quo
        MOV AH, 0
        INC county
        JMP output2

      print:
        CMP county, 0
          JE exit
        POP BX
        MOV DX, BX
        MOV AH, 02h
        INT 21H
        DEC county
        JMP print
      
      exit:
  ENDM

  REMOVE_ROW MACRO siVal
    LOCAL ML1
    PUSH SI
      MOV SI, siVal
      .IF (SI >= 0 && SI <= 84)
        MOV siVal, 0  
      .ELSEIF (SI > 84 && SI <= 168)
        MOV siVal, 84
      .ELSEIF (SI > 168 && SI <= 252)
        MOV siVal, 168
      .ELSEIF (SI > 252 && SI <= 336)
        MOV siVal, 252
      .ELSEIF (SI > 336 && SI <= 420)
        MOV siVal, 336
      .ELSEIF (SI > 420 && SI <= 504)
        MOV siVal, 420
      .ELSE
        MOV siVal, 504
      .ENDIF

    PUSH CX
      MOV CX, 7
      MOV SI, siVal
      ML1:
        .IF (WORD PTR grid[SI+10] != 1)
          MOV WORD PTR grid[SI+8], 0
        .ENDIF
        ADD SI, SIZEOF Box
      LOOP ML1
    POP CX
    POP SI
  ENDM

  SWAP_COL MACRO candyOneSI
    CALL REP_GRID
    MOV SI, candyOneSI
    REMOVE_CANDY WORD PTR dupGrid[SI-(SIZEOF Box * 7)], WORD PTR dupGrid[(SI-(SIZEOF Box * 7))+2], WORD PTR dupGrid[(SI-(SIZEOF Box * 7))+4], WORD PTR dupGrid[(SI-(SIZEOF Box * 7))+6] 
    PUSH CX
      MOV CX, WORD PTR grid[(SI-(SIZEOF Box * 7))+8]
      MOV WORD PTR grid[(SI-(SIZEOF Box * 7))+8], 0
      MOV WORD PTR grid[SI+8], CX
      .IF (CX == 1)
        CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ELSEIF (CX == 2)
        CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ELSEIF (CX == 3)
        CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ELSEIF (CX == 4)
        CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ELSEIF (CX == 5)
        CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ENDIF
    POP CX
  ENDM

  ; Delay Macro (runs a useless loop to pass an amount of time)
  ; takes the number to run the loop
	DELAY MACRO a
	LOCAL S1, S2
	MOV CX, a
		S1:
			MOV DX, a
			S2:
				DEC DX
				CMP DX, 0
				JNE S2
			Loop S1
	ENDM

  ; Macro to decode the row and column of a given click
  ; Takes cordinates from mouse as input and returns the candy number in candy variable 
  DECODE_POSITION MACRO mouseX, mouseY, candy
    MOV foundPos, 0 ; Flag to check if candy is found
    MOV countPos, 0 ; Loop variable that counts from 0 to 49
    CALL REP_GRID ; Duplicating the grid to get the latest copy

    ; Preseving the original values of the registers
    PUSH CX 
    PUSH DX

    MOV CX, mouseX
    SAR CX, 1 ; Dividing by 2 as CX is doubled in video mode 13
    MOV DX, mouseY

    MOV SI, 0 ; Resetting SI
    .WHILE(foundPos==0 && countPos < 49) ; Loop only runs if position is not found or countPos is less than grid's max index
      ; Condition that checks that mouse click is in the x and y axis of a cell in the grid
      .IF(CX >= WORD PTR dupGrid[SI] && CX <= WORD PTR dupGrid[SI+2] && DX>= WORD PTR dupGrid[SI+4] && DX<= WORD PTR dupGrid[SI+6] && WORD PTR dupGrid[SI+10]==0)
        MOV foundPos, 1
        MOV candy, SI
      .ENDIF
      INC countPos
      ADD SI, SIZEOF Box ; Incrementing SI
    .ENDW
    
    ; Returning registers to their original value
    POP DX
    POP CX
  ENDM

  ; Macro to print black color over a candy (I.E remove a candy from the grid)
  ; Takes the box cordinate as input
  REMOVE_CANDY MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2
    MOV AH, 0ch
    MOV AL, 00h
    MOV BX, 0

    ; Adjusting the cordinates so edges stay intact
    ADD xStart, 2
    ADD yStart, 2
    SUB xEnd, 2
    SUB yEnd, 2

    MOV DX, xStart
    MOV copy, DX

    L1:
      MOV DX, copy
      MOV xStart, DX
      INC yStart
      L2:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L2
      MOV CX, yStart
      CMP CX, yEnd
    JBE L1
  ENDM

  ; Macro to create rectangle shape in the grid
  ; Takes in cordinates of the cell as input
  CREATE_RECTANGLE MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2
    MOV AH, 0ch
    MOV AL, 3h
    MOV BX, 0

    ; Adjusting the cordinates so edges stay intact
    ADD xStart, 7
    ADD yStart, 6
    SUB xEnd, 7
    SUB yEnd, 7

    MOV DX, xStart
    MOV copy, DX

    L1:
      MOV DX, copy
      MOV xStart, DX
      INC yStart
      L2:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L2
      MOV CX, yStart
      CMP CX, yEnd
    JBE L1
  ENDM

  ; Macro to create triangle shape in the grid
  ; Takes in cordinates of the cell as input
  CREATE_TRIANGLE MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2
    MOV AH, 0ch
    MOV AL, 5h
    MOV BX, 0

    ; Adjusting the cordinates so edges stay intact
    ADD xStart, 15
    SUB xEnd, 15
    ADD yStart, 5
    SUB yEnd, 5

    MOV CX, yEnd
    .WHILE(yStart<=CX)
      PUSH CX
      MOV DX, xStart
      PUSH DX
      L2:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L2
      POP DX
      MOV xStart, DX
      POP CX
      DEC xStart
      INC xEnd
      INC yStart
    .ENDW

  ENDM

  ; Macro to create triangle shape in the grid
  ; Takes in cordinates of the cell as input
  CREATE_PENTAGON MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2, L3, L4
    MOV AH, 0ch
    MOV AL, 7h
    MOV BX, 0

    ; Adjusting the cordinates so edges stay intact
    ADD xStart, 15
    SUB xEnd, 15
    ADD yStart, 5
    SUB yEnd, 5

      MOV CX, yEnd
      SUB CX, 4
      .WHILE(yStart<=CX)
        PUSH CX
        MOV DX, xStart
        PUSH DX
        L2:
          MOV CX, xStart
          MOV DX, yStart
          INT 10h
          INC xStart
          MOV DX, xEnd
          CMP DX, xStart
        JAE L2
        POP DX
        MOV xStart, DX
        POP CX
        DEC xStart
        INC xEnd
        INC yStart
      .ENDW

    INC xStart
    DEC yStart

    MOV DX, xStart
    MOV copy, DX
    DEC xEnd

    L3:
      MOV DX, copy
      MOV xStart, DX
      INC yStart
      L4:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L4
      MOV CX, yStart
      CMP CX, yEnd
    JBE L3

  ENDM

  CREATE_INVERTEDTRI MACRO xStart, xEnd, yStart, yEnd
    LOCAL L6
    MOV AH, 0ch
    MOV AL, 12h
    MOV BX, 0

    ADD xStart, 9
    SUB xEnd, 9
    ADD yStart, 10
    SUB yEnd, 5

    MOV CX, yEnd
    .WHILE(yStart<=CX)
      PUSH CX
      PUSH xStart
      L6:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L6
      POP xStart
      POP CX
      INC xStart
      DEC xEnd
      INC yStart
    .ENDW
  ENDM


  CREATE_HEXAGON MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2, L3, L4, L5, L6

    MOV DX, xStart
    MOV xStartCopy, DX

    MOV DX, xEnd
    MOV xEndCopy, DX

    MOV DX, yStart
    MOV yStartCopy, DX

    MOV DX, yEnd
    MOV yEndCopy, DX

    CREATE_INVERTEDTRI xStart, xEnd, yStart, yEnd

    MOV DX, xStartCopy
    MOV xStart, DX

    MOV DX, xEndCopy
    MOV xEnd, DX

    MOV DX, yStartCopy
    MOV yStart, DX

    MOV DX, yEndCopy
    MOV yEnd, DX

    MOV AH, 0ch
    MOV AL, 12h
    MOV BX, 0

    ADD xStart, 15
    SUB xEnd, 15
    ADD yStart, 5
    SUB yEnd, 5

    MOV CX, yEnd
    SUB CX, 4
    .WHILE(yStart<=CX)
      PUSH CX
      PUSH xStart
      L2:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L2
      POP xStart
      POP CX
      DEC xStart
      INC xEnd
      INC yStart
    .ENDW

    INC xStart
    DEC yStart

    MOV DX, xStart
    MOV copy, DX

    SUB yEnd, 3
    DEC xEnd

    L3:
      MOV DX, copy
      MOV xStart, DX
      INC yStart
      L4:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        INC xStart
        MOV DX, xEnd
        CMP DX, xStart
      JAE L4
      MOV CX, yStart
      CMP CX, yEnd
    JBE L3

  ENDM

  CREATE_BOMB MACRO xStart, xEnd, yStart, yEnd
    LOCAL L1, L2
    MOV AH, 0ch
    MOV AL, 0Eh
    MOV BX, 0

    ADD xStart, 5
    ADD yStart, 4
    SUB xEnd, 5
    SUB yEnd, 5

    MOV DX, xStart
    MOV copy, DX

    L1:
      MOV DX, copy
      MOV xStart, DX
      INC yStart
      L2:
        MOV CX, xStart
        MOV DX, yStart
        INT 10h
        ADD xStart, 2
        MOV DX, xEnd
        CMP DX, xStart
      JAE L2
      MOV CX, yStart
      CMP CX, yEnd
    JBE L1
    
  ENDM

  ; Starting the main program
  MAIN PROC
    LOCAL count: WORD  
    ; Boiler Plate
    MOV AX, @DATA
    MOV DS, AX

    ; Setting the video mode
    MOV AH, 00h
    MOV AL, 13 ; 320x200
    INT 10h

    ; Cordinates of straight line above game name
    MOV x, 0 ; X-cordinate
    MOV y, 20 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing the line above name
    CALL PRINT_LINE

    ; Setting the Cursor to print name
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 3
    MOV DL, 15
    INT 10h

    ; Printing name
    MOV DX, OFFSET gameName
    MOV AH, 09h
    INT 21h

    ; Cordinates of straight line below game name
    MOV x, 0 ; X-cordinate
    MOV y, 35 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing line below name
    CALL PRINT_LINE

    ; Getting player name
    CALL GET_PLAYER_NAME

    ; Welcome routine
    CALL WELCOME_PLAYER

    ; Print game rules
    CALL PRINT_GAME_RULES

    ; Start Level One
    CALL LEVEL_ONE

    .IF (levelOneCurrScore < 20)
      JMP endGame
    .ENDIF

    ; Start Level Two
    CALL LEVEL_TWO

    .IF (levelTwoCurrScore < 20)
      JMP endGame
    .ENDIF

    ; Start Level Three
    CALL LEVEL_THREE

    endGame:
      ; Exit
      MOV AH, 4ch
      INT 21h
  MAIN ENDP

  ; Function to print straight line (Uses the x, y and cmpX)
  PRINT_LINE PROC
    MOV AH, 0ch
    MOV AL, 0Fh
    MOV BX, pageNum

    ; Loop to print line
    L1:
      MOV CX, x
      MOV DX, y
      INT 10h
      INC x
      CMP x, 640
      JNE L1
    
    RET
  PRINT_LINE ENDP

  GET_PLAYER_NAME PROC
    ; Setting the Cursor to print prompt
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 5
    MOV DL, 0
    INT 10h

    ; Prompt the user for input
    MOV DX, OFFSET getNamePrompt
    MOV AH, 09h
    INT 21h

    ; Getting the array offset
    MOV SI, OFFSET playerName

    ; Getting user input in playerName Array
    input:
      MOV AH, 01h
      INT 21h
      CMP AL, 13
      JE return
      MOV [SI], AL
      INC SI
      JMP input

    return:
      RET
  GET_PLAYER_NAME ENDP

  WELCOME_PLAYER PROC

    ; Cordinates of straight line above welcome player
    MOV x, 0
    MOV y, 75
    MOV pageNum, 0 ; Page Number

    ; Printing the straight line above welcome prompt
    CALL PRINT_LINE

    ; Setting the Cursor to print prompt
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 10
    MOV DL, 13
    INT 10h

    ; Printing the welcome prompt
    MOV DX, OFFSET welcomePrompt
    MOV AH, 09h
    INT 21h

    ; Printing the player name
    MOV DX, OFFSET playerName
    MOV AH, 09h
    INT 21h

    ; Cordinates of straight line above welcome player
    MOV x, 0
    MOV y, 90
    MOV pageNum, 0 ; Page Number

    ; Printing the straight line below welcome prompt
    CALL PRINT_LINE

    ; Setting the Cursor to print prompt
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 12
    MOV DL, 0
    INT 10h

    MOV DX, OFFSET pressKeyPrompt
    MOV AH, 09h
    INT 21H

    MOV AH, 01h
    INT 21h

    RET
  WELCOME_PLAYER ENDP

  PRINT_GAME_RULES PROC
    ; Clearing the screen
    MOV AH, 00h
    MOV AL, 06h
    INT 10h

    ; Cordinates of straight line above game name
    MOV x, 0 ; X-cordinate
    MOV y, 35 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing the line above name
    CALL PRINT_LINE

    ; Setting the Cursor to print name
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 5
    MOV DL, 35
    INT 10h

    ; Printing name
    MOV DX, OFFSET gameRulesPrompt ; Game rules
    MOV AH, 09h
    INT 21h
    
    ; Cordinates of straight line below game name
    MOV x, 0 ; X-cordinate
    MOV y, 50 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing line below name
    CALL PRINT_LINE

    ; Setting the Cursor to print the rules
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 7
    MOV DL, 0
    INT 10h

    ; Printing rules
    MOV DX, OFFSET ruleOne
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleTwo
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleThree
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleFour
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleFive
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleSix
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleSeven
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET ruleEight
    CALL PRINT_SINGLE_RULE

    MOV DX, OFFSET pressKeyPrompt
    CALL PRINT_SINGLE_RULE

    MOV AH, 01h
    INT 21h

    RET
  PRINT_GAME_RULES ENDP

  PRINT_SINGLE_RULE PROC ; Function prints the array in DX and a newline
    MOV AH, 09h
    INT 21h
    MOV AH, 02h
    MOV DL, 10
    INT 21h
    RET
  PRINT_SINGLE_RULE ENDP

  LEVEL_ONE PROC
    LOCAL count: WORD
    ; Clearing the screen
    MOV AH, 00h
    MOV AL, 13
    INT 10h

    ; Cordinates of straight line above game name
    MOV x, 0 ; X-cordinate
    MOV y, 20 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing the line above name
    CALL PRINT_LINE

    ; Setting the Cursor to print name
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 3
    MOV DL, 15
    INT 10h

    ; Printing Title Prompt
    MOV DX, OFFSET levelOnePrompt
    MOV AH, 09h
    INT 21h
    
    ; Cordinates of straight line below game name
    MOV x, 0 ; X-cordinate
    MOV y, 35 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing line below name
    CALL PRINT_LINE

    ; Generating the array with cordinates of each box
    CALL GENERATE_CELLS

    ; Printing the grid
    CALL PRINT_GRID

    ; Adding Candies to the board 
    CALL POPULATE_CANDIES
    CALL CHECK_COMBOS
    CALL REMOVE_COMBOS

    ; Printing details (Such as name and no of moves)
    CALL PRINT_DETAILS

    MOV movesLeft, 15
    MOV count, 0
    MOV levelScore, 0

    .WHILE (movesLeft > 0)
      .WHILE (count < 20)
        CALL CHECK_COMBOS
        CALL REMOVE_COMBOS
        CALL REPOP_GRID
        INC count
      .ENDW
      MOV count, 0
      CALL SWAP
      DEC movesLeft
      CALL PRINT_DETAILS
    .ENDW

    PUSH DX
    MOV DX, levelScore    
    MOV levelOneCurrScore, DX
    POP DX

    RET
  LEVEL_ONE ENDP

  GENERATE_CELLS PROC
    LOCAL counter: WORD
    MOV SI, 0
    MOV CX, 49

    MOV counter, 0
    MOV BX, 10
    MOV DX, 50

    L1:
      MOV WORD PTR grid[SI], BX
      MOV WORD PTR grid[SI+4], DX
      ADD BX, 30
      MOV WORD PTR grid[SI+2], BX
      PUSH DX
      ADD DX, 20
      MOV WORD PTR grid[SI+6], DX
      POP DX
      INC counter
      .IF(counter==7)
        MOV counter, 0
        ADD DX, 20
        MOV BX, 10
      .ENDIF
      ADD SI, SIZEOF Box
    LOOP L1
    RET
  GENERATE_CELLS ENDP

  REP_GRID PROC
    MOV SI, 0
    MOV CX, 49

    L1:
      MOV DX, WORD PTR grid[SI]
      MOV WORD PTR dupGrid[SI], DX

      MOV DX, WORD PTR grid[SI+4]
      MOV WORD PTR dupGrid[SI+4], DX

      MOV DX, WORD PTR grid[SI+2]
      MOV WORD PTR dupGrid[SI+2], DX

      MOV DX, WORD PTR grid[SI+6]
      MOV WORD PTR dupGrid[SI+6], DX

      MOV DX, WORD PTR grid[SI+8]
      MOV WORD PTR dupGrid[SI+8], DX

      MOV DX, WORD PTR grid[SI+10]
      MOV WORD PTR dupGrid[SI+10], DX

      ADD SI, SIZEOF Box
    LOOP L1

    RET
  REP_GRID ENDP

  PRINT_GRID PROC
    LOCAL xVal: WORD, firstRun: BYTE

    MOV AH, 0ch
    MOV AL, 0Fh
    MOV BX, 0

    CALL REP_GRID

    MOV firstRun, 0
    MOV SI, 0
    MOV CX, 49

    ; Loop to print line
    L1:
      CMP firstRun, 0
        JE incFirstRun
      ADD SI, SIZEOF Box
      incFirstRun:
        INC firstRun
        MOV DX, WORD PTR dupGrid[SI]
        MOV xVal, DX
        PUSH CX
      L2:
        MOV CX, xVal
        MOV DX, WORD PTR dupGrid[SI+4]
        INT 10h
        INC xVal
        MOV DX, WORD PTR dupGrid[SI+2]
        CMP DX, xVal
      JNE L2
      POP CX
    LOOP L1

    ; LAST LINE
    SUB SI, SIZEOF Box * 8
    MOV CX, 8
    L5:
      ADD SI, SIZEOF Box
      MOV DX, WORD PTR dupGrid[SI]
      MOV xVal, DX
      PUSH CX
      L6:
        MOV CX, xVal
        MOV DX, WORD PTR dupGrid[SI+6]
        INT 10h
        INC xVal
        MOV DX, WORD PTR dupGrid[SI+2]
        CMP DX, xVal
      JNE L6
      POP CX
    LOOP L5

    MOV firstRun, 0
    MOV SI, 0
    MOV CX, 49

    L3:
      CMP firstRun, 0
        JE incFirstRunTwo
      ADD SI, SIZEOF Box
      incFirstRunTwo:
        INC firstRun
        MOV DX, WORD PTR dupGrid[SI+4]
        MOV xVal, DX
        PUSH CX
      L4:
        MOV CX, WORD PTR dupGrid[SI] 
        MOV DX, xVal
        INT 10h
        INC xVal
        MOV DX, WORD PTR dupGrid[SI+6]
        CMP DX, xVal
      JNE L4
      POP CX
    LOOP L3

    ; LAST LINE
    SUB SI, SIZEOF Box * 48
    MOV CX, 48
    L7:
      ADD SI, SIZEOF Box
      MOV DX, WORD PTR dupGrid[SI+4]
      MOV xVal, DX
      PUSH CX
      L8:
        MOV CX, WORD PTR dupGrid[SI+2]
        MOV DX, xVal
        INT 10h
        INC xVal
        MOV DX, WORD PTR dupGrid[SI+6]
        CMP DX, xVal
      JNE L8
      POP CX
    LOOP L7

    RET
  PRINT_GRID ENDP

  GENERATE_RANDOMNUM PROC
    LOCAL primeOne: WORD
    again:
      MOV AH, 00h   ; interrupt to get system timer in CX:DX 
      INT 1AH
      MOV primeOne, DX
      MOV AX, 25173          ; LCG Multiplier
      MUL primeOne      ; DX:AX = LCG multiplier * seed
      ADD AX, 13849          ; Add LCG increment value
      ; Modulo 65536, AX = (multiplier*seed+increment) mod 65536
      MOV primeOne, AX          ; Update seed = return value
      XOR DX, DX
      MOV CX, 45    
      DIV CX ; here dx contains the remainder - from 0 to 44
      .IF (DX==0)
        DELAY 1000
        JMP again
      .ENDIF
    RET
  GENERATE_RANDOMNUM ENDP

  POPULATE_CANDIES PROC
    LOCAL count: WORD
    CALL REP_GRID
    MOV count, 0
    MOV SI, 0

    L1:
      INC count
      DELAY 500
      CALL GENERATE_RANDOMNUM

      .IF (DL>0 && DL<10)
        CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        MOV WORD PTR grid[SI+8], 1
      .ELSEIF (DL>9 && DL<20)
        CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        MOV WORD PTR grid[SI+8], 2
      .ELSEIF (DL>19 && DL<30)
        CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        MOV WORD PTR grid[SI+8], 3
      .ELSEIF (DL>29 && DL<40)
        CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        MOV WORD PTR grid[SI+8], 4
      .ELSEIF (DL>39 && DL<45)
        CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        MOV WORD PTR grid[SI+8], 5
      .ENDIF

      MOV WORD PTR grid[SI+10], 0

      ADD SI, SIZEOF Box
      CMP count, 49
    JB L1
    RET
  POPULATE_CANDIES ENDP

  POPULATE_CANDIES_TWO PROC
    LOCAL count: WORD
    CALL REP_GRID
    MOV count, 0
    MOV SI, 0

    L1:
      .IF (count!=0 && count!=3 && count!=6 && count!=7 && count !=13 && count!=21 && count!=27 && count!=35 && count!=41 && count!=42 && count!=45 && count!=48)
        DELAY 1000
        CALL GENERATE_RANDOMNUM
        .IF (DL>0 && DL<10)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1
        .ELSEIF (DL>9 && DL<20)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (DL>19 && DL<30)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3
        .ELSEIF (DL>29 && DL<40)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4
        .ELSEIF (DL>39 && DL<45)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5
        .ENDIF
      .ELSE
        MOV WORD PTR grid[SI+10], 1
      .ENDIF
      INC count
      ADD SI, SIZEOF Box
      CMP count, 49
    JB L1
    RET
  POPULATE_CANDIES_TWO ENDP

  POPULATE_CANDIES_THREE PROC
    LOCAL count: WORD
    CALL REP_GRID
    MOV count, 0
    MOV SI, 0

    L1:
      .IF (count!=3 && count!=10 && count!=17 && !(count > 20 && count < 28) && count !=31 && count!=38 && count!=45)
        DELAY 300
        CALL GENERATE_RANDOMNUM
        .IF (DL>0 && DL<10)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1
        .ELSEIF (DL>9 && DL<20)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (DL>19 && DL<30)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3
        .ELSEIF (DL>29 && DL<40)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4
        .ELSEIF (DL>39 && DL<45)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5
        .ELSE
          SUB SI, SIZEOF Box  
        .ENDIF
      .ELSE
        MOV WORD PTR grid[SI+10], 1
      .ENDIF
      INC count
      ADD SI, SIZEOF Box
      CMP count, 49
    JB L1
    RET
  POPULATE_CANDIES_THREE ENDP

  PRINT_DETAILS PROC
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 7
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET playerNamePrompt
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 9
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET playerName
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 11
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET requiredScorePrompt
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 13
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET levelOneScore
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 15
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET currScorePrompt
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 17
    MOV DL, 28
    INT 10h

    ; OUTPUT SCORE HERE
    MULTI_DIGIT_OUTPUT levelScore

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 19
    MOV DL, 28
    INT 10h

    MOV AH, 09h
    MOV DX, OFFSET movesLeftPrompt
    INT 21h

    MOV AH, 02h
    MOV BH, 0
    MOV DH, 21
    MOV DL, 28
    INT 10h

    ; OUTPUT MOVES LEFT HERE
    MULTI_DIGIT_OUTPUT movesLeft

    RET
  PRINT_DETAILS ENDP

  LEVEL_TWO PROC
    LOCAL count: WORD
    ; Clearing the screen
    MOV AH, 00h
    MOV AL, 13
    INT 10h

    ; Cordinates of straight line above game name
    MOV x, 0 ; X-cordinate
    MOV y, 20 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing the line above name
    CALL PRINT_LINE

    ; Setting the Cursor to print name
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 3
    MOV DL, 15
    INT 10h

    ; Printing Title Prompt
    MOV DX, OFFSET levelTwoPrompt
    MOV AH, 09h
    INT 21h
    
    ; Cordinates of straight line below game name
    MOV x, 0 ; X-cordinate
    MOV y, 35 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing line below name
    CALL PRINT_LINE

    ; Generating the array with cordinates of each box
    CALL GENERATE_CELLS

    ; Printing the grid
    CALL PRINT_GRID

    ; Adding Candies to the board 
    CALL POPULATE_CANDIES_TWO

    CALL CHECK_COMBOS
    CALL REMOVE_COMBOS

    ; Printing details (Such as name and no of moves)
    MOV levelScore, 0
    CALL PRINT_DETAILS

    MOV movesLeft, 15
    MOV count, 0

    .WHILE (movesLeft > 0)
      .WHILE (count < 20)
        CALL CHECK_COMBOS
        CALL REMOVE_COMBOS
        CALL REPOP_GRID
        INC count
      .ENDW
      MOV count, 0
      CALL SWAP
      DEC movesLeft
      CALL PRINT_DETAILS
    .ENDW

    PUSH DX
    MOV DX, levelScore    
    MOV levelTwoCurrScore, DX
    POP DX

    RET
  LEVEL_TWO ENDP

  LEVEL_THREE PROC
    LOCAL count: WORD
    ; Clearing the screen
    MOV AH, 00h
    MOV AL, 13
    INT 10h

    ; Cordinates of straight line above game name
    MOV x, 0 ; X-cordinate
    MOV y, 20 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing the line above name
    CALL PRINT_LINE

    ; Setting the Cursor to print name
    MOV AH, 02h
    MOV BH, 0
    MOV DH, 3
    MOV DL, 15
    INT 10h

    ; Printing Title Prompt
    MOV DX, OFFSET levelThreePrompt
    MOV AH, 09h
    INT 21h
    
    ; Cordinates of straight line below game name
    MOV x, 0 ; X-cordinate
    MOV y, 35 ; Y-cordinate
    MOV pageNum, 0 ; Page Number

    ; Printing line below name
    CALL PRINT_LINE

    ; Generating the array with cordinates of each box
    CALL GENERATE_CELLS

    ; Printing the grid
    CALL PRINT_GRID

    ; Adding Candies to the board 
    CALL POPULATE_CANDIES_THREE

    ; Printing details (Such as name and no of moves)
    MOV levelScore, 0
    CALL PRINT_DETAILS

    MOV movesLeft, 15
    MOV count, 0

    .WHILE (movesLeft > 0)
      .WHILE (count < 20)
        CALL CHECK_COMBOS
        CALL REMOVE_COMBOS
        CALL REPOP_GRID
        INC count
      .ENDW
      MOV count, 0
      CALL SWAP
      DEC movesLeft
      CALL PRINT_DETAILS
    .ENDW

    PUSH DX
    MOV DX, levelScore    
    MOV levelThreeCurrScore, DX
    POP DX
    RET
  LEVEL_THREE ENDP

  SWAP PROC
    LOCAL candyOneSI: WORD, candyTwoSI: WORD, mouseX: WORD, mouseY: WORD, candyNum: WORD, tempCandy: WORD
    MOV candyNum, 0
    MOV tempCandy, 0

    reset:
      MOV BX, 0
      MOV candyOneSI, 50
      MOV candyTwoSI, 50

    getFirstClick:
      MOV AX, 01h
      INT 33h

      .WHILE(BX!=1)
        MOV AX, 03h
        INT 33h
        MOV mouseX, CX
        MOV mouseY, DX
      .ENDW

      DECODE_POSITION mouseX, mouseY, candyOneSI
      .IF (candyOneSI==50)
        DELAY 500
        MOV BX, 0
        JMP getFirstClick
      .ENDIF

    DELAY 500

    getSecondClick:
      MOV BX, 0

      .WHILE(BX!=1)
        MOV AX, 03h
        INT 33h
        MOV mouseX, CX
        MOV mouseY, DX
      .ENDW

      DECODE_POSITION mouseX, mouseY, candyTwoSI
      .IF (candyTwoSI==50)
        DELAY 500
        JMP reset
      .ENDIF

      ; Check weather the candies selected are horizontally or vertically adjustant
      ; Horizontal Check
      MOV CX, candyOneSI
      ADD CX, 12
      .IF (CX==candyTwoSI)
        PUSH SI
          MOV SI, CX
          .IF (WORD PTR grid[SI+8] == 5 || WORD PTR grid[( SI-12 )+8] == 5)
            REMOVE_ROW SI
            ; Setting the Pointer
            MOV AX, 04
            MOV CX, 0
            MOV DX, 0
            INT 33h
            ADD levelScore, 7
            JMP return
          .ENDIF
        POP SI
        JMP adjacent
      .ENDIF

      MOV CX, candyOneSI
      SUB CX, 12
      .IF (CX==candyTwoSI)
        PUSH SI
          MOV SI, CX
          .IF (WORD PTR grid[SI+8] == 5 || WORD PTR grid[(SI+12)+8] == 5)
            REMOVE_ROW SI
            ; Setting the Pointer
            MOV AX, 04
            MOV CX, 0
            MOV DX, 0
            INT 33h
            ADD levelScore, 7
            JMP return
          .ENDIF
        POP SI
        JMP adjacent
      .ENDIF

      ; Vertical Check
      MOV CX, candyOneSI
      SUB CX, 84
      .IF (CX==candyTwoSI)
        JMP adjacent
      .ENDIF

      MOV CX, candyOneSI
      ADD CX, 84
      .IF (CX==candyTwoSI)
        JMP adjacent
      .ENDIF
      
      INC movesLeft
      JMP return

      adjacent:

        ; Setting the Pointer
        MOV AX, 04
        MOV CX, 0
        MOV DX, 0
        INT 33h

        MOV SI, candyTwoSI
        MOV CX, WORD PTR grid[SI+8]
        MOV candyNum, CX

        MOV SI, candyOneSI
        REMOVE_CANDY WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        PUSH SI
        CALL REP_GRID
        POP SI

        MOV CX, WORD PTR grid[SI+8]
        MOV tempCandy, CX

        .IF (candyNum==1)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1 
        .ELSEIF (candyNum==2)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (candyNum==3)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3 
        .ELSEIF (candyNum==4)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4 
        .ELSEIF (candyNum==5)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5 
        .ENDIF
        
        MOV SI, candyTwoSI
        PUSH SI
        REMOVE_CANDY WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        CALL REP_GRID
        POP SI

        MOV CX, tempCandy
        MOV candyNum, CX

        .IF (candyNum==1)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1 
        .ELSEIF (candyNum==2)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (candyNum==3)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3 
        .ELSEIF (candyNum==4)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4 
        .ELSEIF (candyNum==5)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5 
        .ENDIF

      CALL CHECK_COMBOS
      .IF (combosFound == 0)
        DELAY 1000
        MOV SI, candyTwoSI
        MOV CX, WORD PTR grid[SI+8]
        MOV candyNum, CX

        MOV SI, candyOneSI
        REMOVE_CANDY WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        PUSH SI
        CALL REP_GRID
        POP SI

        MOV CX, WORD PTR grid[SI+8]
        MOV tempCandy, CX

        .IF (candyNum==1)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1 
        .ELSEIF (candyNum==2)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (candyNum==3)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3 
        .ELSEIF (candyNum==4)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4 
        .ELSEIF (candyNum==5)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5 
        .ENDIF
        
        MOV SI, candyTwoSI
        PUSH SI
        REMOVE_CANDY WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
        CALL REP_GRID
        POP SI

        MOV CX, tempCandy
        MOV candyNum, CX

        .IF (candyNum==1)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1 
        .ELSEIF (candyNum==2)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (candyNum==3)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3 
        .ELSEIF (candyNum==4)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4 
        .ELSEIF (candyNum==5)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5 
        .ENDIF     
      .ENDIF

    return:
      RET
  SWAP ENDP

  CHECK_COMBOS PROC
    LOCAL comboCount: WORD, loopCount: WORD, tempCount: WORD
    MOV combosFound, 0
    MOV comboCount, 1
    MOV loopCount, 0
    MOV tempCount, 0

    MOV SI, 0
    .WHILE (tempCount < 6)
      MOV loopCount, 0
      MOV SI, 0
      .WHILE(loopCount < 49)
        GET_MOD loopCount, 7
        .IF(isModZero == 1)
          MOV comboCount, 1
        .ENDIF
        .IF (WORD PTR grid[SI+10] != 1 && WORD PTR grid[SI+8] != 0)
          PUSH CX
          MOV CX, WORD PTR grid[SI+8]
          .IF(CX==WORD PTR grid[SI+SIZEOF Box+8])
            INC comboCount
          .ELSE
            .IF (comboCount >= 3)
              MOV combosFound, 1
              PUSH DX
                MOV DX, comboCount
                ADD levelScore, DX
              POP DX
              PUSH SI
              .WHILE(comboCount > 0)
                MOV WORD PTR grid[SI+8], 0
                SUB SI, SIZEOF Box
                DEC comboCount
              .ENDW
              POP SI
              MOV comboCount, 1
            .ELSE
              MOV comboCount, 1
            .ENDIF
          .ENDIF
          POP CX
        .ELSE
          MOV comboCount, 1
        .ENDIF
        INC loopCount
        ADD SI, SIZEOF Box
      .ENDW
      INC tempCount
    .ENDW

    MOV SI, 0
    MOV loopCount, 0
    MOV comboCount, 1
    MOV tempCount, 1
    MOV BX, 0
    
    .WHILE(loopCount < 49)
      GET_MOD loopCount, 7
      .IF(isModZero == 1)
        MOV comboCount, 1
        MOV SI, 0
        ADD BX, SIZEOF Box
      .ENDIF
      .IF (WORD PTR grid[SI+BX+10] != 1 && WORD PTR grid[SI+BX+8] != 0)
        PUSH CX
        MOV CX, WORD PTR grid[SI+8+BX]
        .IF (CX == WORD PTR grid[8+(SI+SIZEOF Box*7)+BX])
          INC comboCount
        .ELSE
          PUSH SI
          .IF (comboCount >= 3)
            MOV combosFound, 1
            PUSH DX
              MOV DX, comboCount
              ADD levelScore, DX
            POP DX
            .WHILE(comboCount > 0)
              DEC comboCount
              MOV WORD PTR grid[SI+BX+8], 0
              SUB SI, (SIZEOF Box * 7)
            .ENDW
            MOV comboCount, 1
          .ELSE
            MOV comboCount, 1
          .ENDIF
          POP SI
        .ENDIF
        POP CX
      .ELSE
        MOV comboCount, 1
      .ENDIF
      INC loopCount
      INC tempCount
      ADD SI, (SIZEOF Box * 7)
    .ENDW

    RET
  CHECK_COMBOS ENDP

  REMOVE_COMBOS PROC
    LOCAL count: WORD
    MOV count, 0
    CALL REP_GRID

    MOV SI, 0

    .WHILE(count < 49)
      .IF(WORD PTR dupGrid[SI+8]==0)
        REMOVE_CANDY WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
      .ENDIF
      INC count
      ADD SI, SIZEOF Box
    .ENDW

    RET
  REMOVE_COMBOS ENDP  

  ; ADJUST_GRID PROC
  ;   LOCAL count: WORD, tempCount: WORD, countThree: WORD

  ;   MOV count, 0

  ;   MOV BX, ( SIZEOF Box * 7 )
  ;   REMOVE_CANDY WORD PTR grid[12], WORD PTR grid[14], WORD PTR grid[16], WORD PTR grid[18]

    ; .WHILE (countThree < 49)
    ;   MOV tempCount, 0 
    ;   .WHILE (tempCount < 49)
    ;     MOV SI, (SIZEOF Box * 48)
    ;     MOV count, 0
    ;     .WHILE(count < 42)
    ;       .IF (WORD PTR grid[SI+8] == 0)
    ;         PUSH SI
    ;         SWAP_COL SI
    ;         POP SI
    ;       .ENDIF
    ;       SUB SI, SIZEOF Box
    ;       INC count
    ;     .ENDW
    ;     INC tempCount
    ;   .ENDW
    ;   INC countThree
    ; .ENDW

  ;   RET
  ; ADJUST_GRID ENDP

  REPOP_GRID PROC
    LOCAL count: WORD
    CALL REP_GRID
    MOV count, 0

    MOV SI, 0
    .WHILE (count < 49)
      .IF (WORD PTR grid[SI+8] == 0 && WORD PTR grid[SI+10] != 1)
        DELAY 500
        CALL GENERATE_RANDOMNUM

        .IF (DL>0 && DL<10)
          CREATE_RECTANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 1
        .ELSEIF (DL>9 && DL<20)
          CREATE_TRIANGLE WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 2
        .ELSEIF (DL>19 && DL<30)
          CREATE_PENTAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 3
        .ELSEIF (DL>29 && DL<40)
          CREATE_HEXAGON WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 4
        .ELSEIF (DL>39 && DL<45)
          CREATE_BOMB WORD PTR dupGrid[SI], WORD PTR dupGrid[SI+2], WORD PTR dupGrid[SI+4], WORD PTR dupGrid[SI+6]
          MOV WORD PTR grid[SI+8], 5
        .ENDIF
      .ENDIF
      ADD SI, SIZEOF Box
      INC count
    .ENDW
    RET
  REPOP_GRID ENDP
END