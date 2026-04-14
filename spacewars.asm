INCLUDE Irvine/Irvine32.inc


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
    HEALTH_TOP    DWORD 5
    HEALTH_MID    DWORD 3
    HEALTH_BOT    DWORD 1

.CODE

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
        

        EXIT
    MAIN ENDP

END MAIN