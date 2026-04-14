.386
.model flat, stdcall
option casemap :none


; MASM32 includes
include C:\masm32\include\windows.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\gdi32.inc
include C:\masm32\include\masm32.inc

; Relevant libs
includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\gdi32.lib
includelib C:\masm32\lib\masm32.lib




; Constants

MAX_ENEMIES     EQU 30
MAX_ATTACKS     EQU 100


; Structs

Enemy STRUCT
    isActive    BYTE ?             ; 0 for inactive and 1 for active
    padding     BYTE 3 DUP(?)      ; memory efficiency shi so memory aligns better chunk-wise
    enemyType   DWORD ?
    health      DWORD ?
    posx        DWORD ?
    posy        DWORD ?
    shootTimer  DWORD ?
    patternData DWORD ?
Enemy ENDS

EnemyAttack STRUCT
    isActive    BYTE ?
    padding     BYTE 3 DUP(?)
    posx        DWORD ?
    posy        DWORD ?
    velx        DWORD ?
    vely        DWORD ?
EnemyAttack ENDS

BossStruct STRUCT
    isActive    BYTE ?
    padding     BYTE 3 DUP(?)
    part1Health DWORD ?
    part2Health DWORD ?
    part3Health DWORD ?
    phase       DWORD ?            ; Current Attack Pattern of Boss
    phaseTimer  DWORD ?
    posx        DWORD ?
    posy        DWORD ?
BossStruct ENDS

.DATA
    enemyArr Enemy MAX_ENEMIES DUP(<>)
    attackArr EnemyAttack MAX_ATTACKS DUP(<>)
    boss        BossStruct <>

    score       DWORD ?


    START_X     DWORD 100
    START_Y     DWORD 50
    SPACING_X   DWORD 60
    SPACING_Y   DWORD 40
    ROWS        DWORD 3
    COLS        DWORD 10

    ; stats for enemies in diff rows
    HEALTH_TOP  DWORD 5
    HEALTH_MID  DWORD 3
    HEALTH_BOT  DWORD 1


    ; Game State Shii
    enemyDir    DWORD 1         ; 1 for right, -1 for left
    enemySpeed  DWORD 5         ; movement speed
    SCREEN_WIDTH  EQU 800       ; temp screen size for console testing
    SCREEN_HEIGHT EQU 600
    SCREEN_MARGIN EQU 20


    ; temp colors assigned for enemies in diff rows


    ; temp colors assigned for enemies in diff rows
    COLOR_RED    EQU 000000FFh  ; Bottom (not me)
    COLOR_GREEN  EQU 0000FF00h  ; Mid (so mehu)
    COLOR_BLUE   EQU 00FF0000h  ; Top (me frfr)
    COLOR_BLACK  EQU 00000000h  ; Black (background)
    ENEMY_WIDTH  EQU 30
    ENEMY_HEIGHT EQU 20

.CODE


    ; --------------------------------
    ;       Helper Funcs
    ; --------------------------------



    ; Draws a damn rectangle
    ; - Calculate the right and bottom coordinates
    ; - Then invoke Windows API to draw the rectangle

    DrawRect PROC, 
        hdc:DWORD,      ; Handle to Device Context
        x:DWORD, 
        y:DWORD, 
        w:DWORD, 
        h:DWORD,
        color:DWORD
    ;--------------------------------
        local hBrush:DWORD
        local hOldBrush:DWORD

        pushad
        
        ; create a brush with the color and select it
        invoke CreateSolidBrush, color
        mov hBrush, eax
        invoke SelectObject, hdc, hBrush
        mov hOldBrush, eax

        mov eax, x
        add eax, w      ; Right = x + width
        mov ebx, y
        add ebx, h      ; Bottom = y + height
        
        invoke Rectangle, hdc, x, y, eax, ebx
        
        ; cleanup brush to be pro
        invoke SelectObject, hdc, hOldBrush
        invoke DeleteObject, hBrush

        popad
        ret
    DrawRect ENDP



    ; Renders all active enemies on the screen
    ; - Loops through the enemy array and checks if each enemy is active
    ; - If active, determine the color based on enemy type and draw the rectangle

    RenderEnemies PROC, 
    hdc:DWORD
    ;-------------------
        pushad
        mov esi, OFFSET enemyArr
        mov ecx, MAX_ENEMIES

    L_RENDER:
        cmp [esi].Enemy.isActive, 0
        je NEXT_ENEMY

        .IF [esi].Enemy.enemyType == 2
            mov eax, COLOR_BLUE
        .ELSEIF [esi].Enemy.enemyType == 1
            mov eax, COLOR_GREEN
        .ELSE
            mov eax, COLOR_RED
        .ENDIF
        

        invoke DrawRect, hdc, [esi].Enemy.posx, [esi].Enemy.posy, ENEMY_WIDTH, ENEMY_HEIGHT, eax
        
    NEXT_ENEMY:
        add esi, TYPE Enemy
        loop L_RENDER

        popad
        ret
    RenderEnemies ENDP



    ; Handles collective hive movement for all enemies
    ; - Check if any enemy is hitting the side walls
    ; - Apply movement with direction and speed to all enemies
    ; - If a wall was hit, move all enemies down and flip direction

    UpdateEnemyMovement PROC
    ;-------------------------
        pushad
        
        mov esi, OFFSET enemyArr
        mov ecx, MAX_ENEMIES
        mov ebx, 0              ; Flag: 0 = No wall hit, 1 = Wall hit

    L_CHECK_WALLS:
        cmp [esi].Enemy.isActive, 0
        je NEXT_CHECK
        
        mov eax, [esi].Enemy.posx
        
        ; Check Right Wall
        .IF enemyDir == 1
            add eax, enemySpeed
            .IF eax > (SCREEN_WIDTH - SCREEN_MARGIN)
                mov ebx, 1
                jmp START_MOVE
            .ENDIF
        ; Check Left Wall
        .ELSE
            sub eax, enemySpeed
            .IF sdword ptr eax < SCREEN_MARGIN
                mov ebx, 1
                jmp START_MOVE
            .ENDIF
        .ENDIF

    NEXT_CHECK:
        add esi, TYPE Enemy
        loop L_CHECK_WALLS

    START_MOVE:
        mov esi, OFFSET enemyArr
        mov ecx, MAX_ENEMIES

    L_APPLY_MOVE:
        cmp [esi].Enemy.isActive, 0
        je NEXT_MOVE

        .IF ebx == 1            ; If a wall was hit...
            add [esi].Enemy.posy, 20  ; Move everyone DOWN
        .ELSE                   ; Otherwise...
            mov eax, enemySpeed
            imul eax, enemyDir
            add [esi].Enemy.posx, eax
        .ENDIF

    NEXT_MOVE:
        add esi, TYPE Enemy
        loop L_APPLY_MOVE

        .IF ebx == 1
            neg enemyDir        ; Flip 1 to -1, or -1 to 1
        .ENDIF

        popad
        ret
    UpdateEnemyMovement ENDP



    

    InitWave PROC
        pushad

        mov esi, OFFSET enemyArr
        mov ecx, ROWS
        mov ebx, START_Y

    L_ROWS:
        push ecx 
        mov ecx, COLS  
        mov edx, START_X    

        L_COLS:
            ; Set the enemy to active
            mov [esi].Enemy.isActive, 1


            ;       Procedural Stat Assignment
            ;  - look at stack to get row num
            ;  - assign stats based on row num
            mov eax, [esp]          
            
            .IF eax == 3            ; Top Row
                mov [esi].Enemy.enemyType, 2
                mov eax, HEALTH_TOP
                mov [esi].Enemy.health, eax
            .ELSEIF eax == 2        ; Middle Row
                mov [esi].Enemy.enemyType, 1
                mov eax, HEALTH_MID
                mov [esi].Enemy.health, eax
            .ELSE                   ; Bottom Row
                mov [esi].Enemy.enemyType, 0
                mov eax, HEALTH_BOT
                mov [esi].Enemy.health, eax
            .ENDIF
            
            ; Set the position
            mov eax, edx
            mov [esi].Enemy.posx, eax
            mov eax, ebx
            mov [esi].Enemy.posy, eax
            
            add esi, TYPE Enemy
            add edx, SPACING_X
            
        loop L_COLS 

        add ebx, SPACING_Y
        pop ecx 

    loop L_ROWS

        popad
        ret

    InitWave ENDP


    ; Main shii
    MAIN PROC
        ; get enemies ready
        call InitWave
        
        ; get console handle for drawin shi directly on there
        invoke GetConsoleWindow
        invoke GetDC, eax
        mov ebx, eax            ; save hdc in ebx to use later
        
    GAME_LOOP:
        ; clear the previous frame
        invoke DrawRect, ebx, 0, 0, SCREEN_WIDTH + 50, SCREEN_HEIGHT + 50, COLOR_BLACK

        ; handle everyone movin
        call UpdateEnemyMovement
        
        ; draw the dudes
        invoke RenderEnemies, ebx
        
        ; delay so it doesn't go zoomin instantly
        invoke Sleep, 10        ; 10ms sleep
        
        ; check if we wanna quit (ESC key)
        invoke GetAsyncKeyState, VK_ESCAPE
        test eax, eax
        jz GAME_LOOP
        
        ; cleanup and dip
        invoke ReleaseDC, 0, ebx
        invoke ExitProcess, 0
    MAIN ENDP

END MAIN