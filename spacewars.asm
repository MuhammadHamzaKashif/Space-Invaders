INCLUDE Irvine32.inc


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

Boss STRUCT
    isActive    BYTE ?
    padding     BYTE 3 DUP(?)
    part1Health DWORD ?
    part2Health DWORD ?
    part3Health DWORD ?
    phase       DWORD ?            ; Current Attack Pattern of Boss
    phaseTimer  DWORD ?
    posx        DWORD ?
    posy        DWORD ?

Boss ENDS

.DATA
    enemyArr    Enemy MAX_ENEMIES DUP(<>)
    attackArr   EnemyAttack MAX_ATTACKS DUP(<>)
    boss        Boss <>

    score       DWORD ?

.CODE
    ; Main shii
    MAIN PROC
        

        EXIT
    MAIN ENDP

END MAIN