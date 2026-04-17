.386
.model flat, stdcall
option casemap :none

; Includes
include C:\masm32\include\windows.inc
include C:\masm32\include\kernel32.inc
include C:\masm32\include\user32.inc
include C:\masm32\include\gdi32.inc

includelib C:\masm32\lib\kernel32.lib
includelib C:\masm32\lib\user32.lib
includelib C:\masm32\lib\gdi32.lib

; --------------------------------
; Constants
; --------------------------------
MAX_ENEMIES        EQU 40
MAX_BULLETS        EQU 40
MAX_ENEMY_BULLETS  EQU 300
MAX_STARS          EQU 120
MAX_EXPLOSIONS     EQU 30
MAX_POWERUPS       EQU 5
MAX_BOSS_BEAMS     EQU 5

SCREEN_WIDTH  EQU 800
SCREEN_HEIGHT EQU 600

; Colors
COLOR_RED       EQU 000000FFh
COLOR_GREEN     EQU 0000FF00h
COLOR_BLUE      EQU 00FF0000h
COLOR_YELLOW    EQU 0000FFFFh
COLOR_ORANGE    EQU 0000A5FFh
COLOR_MAGENTA   EQU 00FF00FFh
COLOR_CYAN      EQU 00FFFF00h
COLOR_BLACK     EQU 00000000h
COLOR_WHITE     EQU 00FFFFFFh
COLOR_LIGHTGRAY EQU 00AAAAAAh
COLOR_DARKGRAY  EQU 00555555h
COLOR_DARKRED   EQU 00000088h

ENEMY_WIDTH  EQU 30
ENEMY_HEIGHT EQU 20
PLAYER_WIDTH  EQU 40
PLAYER_HEIGHT EQU 20
BULLET_WIDTH       EQU 4
BULLET_HEIGHT      EQU 12
ENEMY_BULLET_W     EQU 8  
ENEMY_BULLET_H     EQU 16 
POWERUP_SIZE       EQU 12
POWERUP_SPEED      EQU 3

STATE_PLAY EQU 0
STATE_DEAD EQU 1
STATE_WIN  EQU 2
STATE_TITLE EQU 3

; --------------------------------
; Structs (All DWORD aligned)
; --------------------------------
Enemy STRUCT
    isActive DWORD ?
    posx DWORD ?
    posy DWORD ?
    health DWORD ?
Enemy ENDS

Bullet STRUCT
    isActive DWORD ?
    posx DWORD ?
    posy DWORD ?
    vx DWORD ?
    vy DWORD ?
Bullet ENDS

PowerUp STRUCT
    isActive DWORD ?
    posx DWORD ?
    posy DWORD ?
    puType DWORD ? ; 0: Weapon, 1: Health
PowerUp ENDS

Star STRUCT
    posx DWORD ?
    posy DWORD ?
    speed DWORD ?
    starSize DWORD ?
    color DWORD ?
Star ENDS

Explosion STRUCT
    isActive DWORD ?
    posx DWORD ?
    posy DWORD ?
    timer DWORD ?
Explosion ENDS

BossBeam STRUCT
    isActive DWORD ?
    posx DWORD ?
    timer DWORD ?
BossBeam ENDS

; --------------------------------
.DATA
enemyArr       Enemy     MAX_ENEMIES DUP(<>)
bulletArr      Bullet    MAX_BULLETS DUP(<>)
enemyBulletArr Bullet    MAX_ENEMY_BULLETS DUP(<>)
powerupArr     PowerUp   MAX_POWERUPS DUP(<>)
starArr        Star      MAX_STARS DUP(<>)
explosionArr   Explosion MAX_EXPLOSIONS DUP(<>)
bossBeamArr    BossBeam  MAX_BOSS_BEAMS DUP(<>)

; Wave 3 Data (V-Shape Formation)
wave3X DWORD 385, 285, 485, 185, 585, 85, 685, 385, 285, 485
wave3Y DWORD 50,  100, 100, 150, 150, 200, 200, 150, 200, 200

ClassName db "SpaceGameClass",0
AppName   db "MASM Space Game - The Boss Expansion",0

szGameOver db "GAME OVER",0
szWin      db "SECTOR CLEARED! BOSS DEFEATED!",0
szRestart  db "Press 'R' to Restart",0
szTitle    db "SPACE WARS: THE BOSS EXPANSION",0
szControls1 db "ARROWS to Move - SPACE to Shoot",0
szControls2 db "Collect RED CROSS for Health",0
szStartMsg db "Press ENTER to Start",0

; Game State
gameState   DWORD STATE_TITLE
frameCount  DWORD 0
currentWave DWORD 1
healthDropsInWave DWORD 0

; Enemy Stats
enemyDir   DWORD 1
enemySpeed DWORD 3

; Player Stats
playerX       DWORD 380
playerY       DWORD 530
playerSpeed   DWORD 8      
shootCooldown DWORD 0
playerHealth  DWORD 3
weaponLevel   DWORD 1  

; Boss Stats
bossActive   DWORD 0
bossHP       DWORD 50     
bossShieldHP DWORD 0       
bossState    DWORD 0
bossTimer    DWORD 0
bossLaserX   DWORD 0
bossLaserDir DWORD 1

; Boss Special Attack Vars
bossSafeX        DWORD 0
bossSafeY        DWORD 0
pelletX          DWORD 0
pelletY          DWORD 0
targetPelletX    DWORD 0
targetPelletY    DWORD 0
pelletActive     DWORD 0
pelletBurstCount DWORD 0

; Randomizer
randSeed DWORD 12345678h

; --------------------------------
.CODE

WinMain PROTO :DWORD,:DWORD,:DWORD,:DWORD
WndProc PROTO :DWORD,:DWORD,:DWORD,:DWORD

; --- Utility Math & Random ---
Random PROC USES edx
    mov eax, randSeed
    imul eax, 1103515245
    add eax, 12345
    and eax, 7FFFFFFFh
    mov randSeed, eax
    ret
Random ENDP

RandomRange PROC USES ecx edx maxVal:DWORD
    call Random
    shr eax, 8      
    xor edx, edx
    mov ecx, maxVal
    div ecx
    mov eax, edx
    ret
RandomRange ENDP

; --- Graphics ---
DrawRect PROC hdc:DWORD, px:DWORD, py:DWORD, pw:DWORD, ph:DWORD, pColor:DWORD
    LOCAL rc:RECT
    LOCAL hBrush:DWORD
    mov eax, px
    mov rc.left, eax
    add eax, pw
    mov rc.right, eax
    mov eax, py
    mov rc.top, eax
    add eax, ph
    mov rc.bottom, eax
    invoke CreateSolidBrush, pColor
    mov hBrush, eax
    invoke FillRect, hdc, ADDR rc, hBrush
    invoke DeleteObject, hBrush
    ret
DrawRect ENDP

; --- Entity Spawning Functions ---
SpawnExplosion PROC USES esi ecx eax pX:DWORD, pY:DWORD
    mov esi, OFFSET explosionArr
    mov ecx, MAX_EXPLOSIONS
find_exp:
    cmp [esi].Explosion.isActive, 0
    je found_exp
    add esi, TYPE Explosion
    dec ecx
    jnz find_exp
    ret
found_exp:
    mov [esi].Explosion.isActive, 1
    mov eax, pX
    mov [esi].Explosion.posx, eax
    mov eax, pY
    mov [esi].Explosion.posy, eax
    mov [esi].Explosion.timer, 15
    ret
SpawnExplosion ENDP

SpawnEnemyBullet PROC USES esi ecx eX:DWORD, eY:DWORD, vX:DWORD, vY:DWORD
    mov esi, OFFSET enemyBulletArr
    mov ecx, MAX_ENEMY_BULLETS
find_eb:
    cmp [esi].Bullet.isActive, 0
    je found_eb
    add esi, TYPE Bullet
    dec ecx
    jnz find_eb
    ret 
found_eb:
    mov [esi].Bullet.isActive, 1
    mov eax, eX
    mov [esi].Bullet.posx, eax
    mov eax, eY
    mov [esi].Bullet.posy, eax
    mov eax, vX
    mov [esi].Bullet.vx, eax
    mov eax, vY
    mov [esi].Bullet.vy, eax
    ret
SpawnEnemyBullet ENDP

SpawnPowerUp PROC USES esi ecx pX:DWORD, pY:DWORD, pType:DWORD
    mov esi, OFFSET powerupArr
    mov ecx, MAX_POWERUPS
find_pu:
    cmp [esi].PowerUp.isActive, 0
    je found_pu
    add esi, TYPE PowerUp
    dec ecx
    jnz find_pu
    ret
found_pu:
    mov [esi].PowerUp.isActive, 1
    mov eax, pX
    add eax, 9
    mov [esi].PowerUp.posx, eax
    mov eax, pY
    mov [esi].PowerUp.posy, eax
    mov eax, pType
    mov [esi].PowerUp.puType, eax
    ret
SpawnPowerUp ENDP

InitWave PROC USES esi ebx edi
    mov healthDropsInWave, 0
    mov esi, OFFSET enemyArr
    mov ebx, 0

    .IF currentWave == 1
        mov enemySpeed, 3
    .ELSEIF currentWave == 2
        mov enemySpeed, 5  
    .ELSEIF currentWave == 3
        mov enemySpeed, 4
    .ELSEIF currentWave == 4
        mov bossActive, 1
        mov bossHP, 50
        mov bossShieldHP, 25
        mov bossState, 0
        mov bossTimer, 0
        ret 
    .ENDIF

init_loop:
    .IF currentWave == 3
        cmp ebx, 10
        jge done_init
        mov [esi].Enemy.isActive, 1
        mov [esi].Enemy.health, 8
        
        mov eax, ebx
        shl eax, 2 
        mov edi, wave3X[eax]
        mov [esi].Enemy.posx, edi
        mov edi, wave3Y[eax]
        mov [esi].Enemy.posy, edi
    .ELSE
        cmp ebx, 30
        jge done_init
        mov [esi].Enemy.isActive, 1
        mov eax, ebx
        xor edx, edx
        mov edi, 6
        div edi
        
        .IF currentWave == 1
            .IF eax <= 1
                mov [esi].Enemy.health, 5
            .ELSE
                mov [esi].Enemy.health, 3
            .ENDIF
        .ELSE
            .IF eax <= 1
                mov [esi].Enemy.health, 8
            .ELSE
                mov [esi].Enemy.health, 5
            .ENDIF
        .ENDIF

        imul edx, 80
        add edx, 50
        mov [esi].Enemy.posx, edx
        imul eax, 50
        add eax, 50
        mov [esi].Enemy.posy, eax
    .ENDIF

    add esi, TYPE Enemy
    inc ebx
    jmp init_loop
done_init:
    ret
InitWave ENDP

; --- Input Subroutine ---
UpdatePlayer PROC
    invoke GetAsyncKeyState, VK_LEFT
    test eax, 8000h
    jz chk_right
    mov eax, playerX
    sub eax, playerSpeed
    cmp eax, 0
    jl l_bound
    mov playerX, eax
    jmp chk_right
l_bound:
    mov playerX, 0

chk_right:
    invoke GetAsyncKeyState, VK_RIGHT
    test eax, 8000h
    jz chk_up
    mov eax, playerX
    add eax, playerSpeed
    mov ebx, SCREEN_WIDTH
    sub ebx, PLAYER_WIDTH
    cmp eax, ebx
    jg r_bound
    mov playerX, eax
    jmp chk_up
r_bound:
    mov playerX, ebx

chk_up:
    invoke GetAsyncKeyState, VK_UP
    test eax, 8000h
    jz chk_down
    mov eax, playerY
    sub eax, playerSpeed
    cmp eax, 250       
    jl t_bound
    mov playerY, eax
    jmp chk_down
t_bound:
    mov playerY, 250

chk_down:
    invoke GetAsyncKeyState, VK_DOWN
    test eax, 8000h
    jz chk_shoot
    mov eax, playerY
    add eax, playerSpeed
    mov ebx, SCREEN_HEIGHT
    sub ebx, PLAYER_HEIGHT
    cmp eax, ebx
    jg b_bound
    mov playerY, eax
    jmp chk_shoot
b_bound:
    mov playerY, ebx

chk_shoot:
    invoke GetAsyncKeyState, VK_SPACE
    test eax, 8000h
    jz fin_in
    cmp shootCooldown, 0
    jg fin_in
    
    mov ecx, MAX_BULLETS
    mov esi, OFFSET bulletArr
  sb_loop:
    cmp [esi].Bullet.isActive, 0
    je do_sb
    add esi, TYPE Bullet
    dec ecx
    jnz sb_loop
    jmp set_cd
  do_sb:
    mov [esi].Bullet.isActive, 1
    mov eax, playerX
    add eax, 18
    mov [esi].Bullet.posx, eax
    mov eax, playerY
    mov [esi].Bullet.posy, eax
    mov [esi].Bullet.vx, 0
    mov [esi].Bullet.vy, -12 
    
    .IF weaponLevel >= 2
      mov esi, OFFSET bulletArr
      mov ecx, MAX_BULLETS
    sb_l2:
      cmp [esi].Bullet.isActive, 0
      je do_sb2
      add esi, TYPE Bullet
      dec ecx
      jnz sb_l2
      jmp set_cd
    do_sb2:
      mov [esi].Bullet.isActive, 1
      mov eax, playerX
      add eax, 8
      mov [esi].Bullet.posx, eax
      mov eax, playerY
      mov [esi].Bullet.posy, eax
      mov [esi].Bullet.vx, 0
      mov [esi].Bullet.vy, -12

      .IF weaponLevel >= 3
        mov esi, OFFSET bulletArr
        mov ecx, MAX_BULLETS
      sb_l3:
        cmp [esi].Bullet.isActive, 0
        je do_sb3
        add esi, TYPE Bullet
        dec ecx
        jnz sb_l3
        jmp set_cd
      do_sb3:
        mov [esi].Bullet.isActive, 1
        mov eax, playerX
        add eax, 28
        mov [esi].Bullet.posx, eax
        mov eax, playerY
        mov [esi].Bullet.posy, eax
        mov [esi].Bullet.vx, 0
        mov [esi].Bullet.vy, -12
      .ENDIF
    .ENDIF

set_cd:
    .IF weaponLevel == 1
        mov shootCooldown, 10
    .ELSEIF weaponLevel == 2
        mov shootCooldown, 7
    .ELSE
        mov shootCooldown, 4
    .ENDIF

fin_in:
    cmp shootCooldown, 0
    je upd_done
    dec shootCooldown
upd_done:
    ret
UpdatePlayer ENDP

; --- Movement Subroutines ---
UpdateBullets PROC USES esi ecx
    mov esi, OFFSET bulletArr
    mov ecx, MAX_BULLETS
ub_p:
    cmp [esi].Bullet.isActive, 0
    je nxt_bp
    mov eax, [esi].Bullet.vy
    add [esi].Bullet.posy, eax
    cmp [esi].Bullet.posy, 0
    jl kill_bp
    jmp nxt_bp
kill_bp:
    mov [esi].Bullet.isActive, 0
nxt_bp:
    add esi, TYPE Bullet
    dec ecx
    jnz ub_p

    mov esi, OFFSET enemyBulletArr
    mov ecx, MAX_ENEMY_BULLETS
ub_e:
    cmp [esi].Bullet.isActive, 0
    je nxt_be
    mov eax, [esi].Bullet.vx
    add [esi].Bullet.posx, eax
    mov eax, [esi].Bullet.vy
    add [esi].Bullet.posy, eax
    
    cmp [esi].Bullet.posy, SCREEN_HEIGHT
    jg kill_be
    cmp [esi].Bullet.posy, -20
    jl kill_be
    cmp [esi].Bullet.posx, -20
    jl kill_be
    cmp [esi].Bullet.posx, SCREEN_WIDTH
    jg kill_be
    
    jmp nxt_be
kill_be:
    mov [esi].Bullet.isActive, 0
nxt_be:
    add esi, TYPE Bullet
    dec ecx
    jnz ub_e
    ret
UpdateBullets ENDP

UpdateEnemies PROC USES esi ecx ebx edi
    LOCAL alive:DWORD
    mov alive, 0
    mov edx, 0 
    mov esi, OFFSET enemyArr
    mov ecx, MAX_ENEMIES

mv_e:
    cmp [esi].Enemy.isActive, 0
    je skp_e
    inc alive

    .IF currentWave < 4
        invoke RandomRange, 400
        cmp eax, 0
        jne no_sh
        mov eax, [esi].Enemy.posx
        add eax, 11
        mov ebx, [esi].Enemy.posy
        add ebx, 20
        invoke SpawnEnemyBullet, eax, ebx, 0, 10  
    no_sh:
    .ENDIF

    .IF currentWave == 1 || currentWave == 3
        mov eax, enemySpeed
        imul eax, enemyDir
        add [esi].Enemy.posx, eax
    .ELSEIF currentWave == 2
        mov eax, enemySpeed
        imul eax, enemyDir
        add [esi].Enemy.posx, eax
        mov eax, frameCount
        and eax, 32
        .IF eax == 0
            add [esi].Enemy.posy, 1
        .ELSE
            sub [esi].Enemy.posy, 1
        .ENDIF
    .ENDIF

    mov eax, [esi].Enemy.posx
    add eax, ENEMY_WIDTH
    cmp eax, SCREEN_WIDTH
    jl c_lf
    mov edx, 1
    jmp skp_e
c_lf:
    cmp [esi].Enemy.posx, 0
    jg skp_e
    mov edx, 1

skp_e:
    add esi, TYPE Enemy
    dec ecx
    jnz mv_e

    .IF currentWave != 4
        cmp alive, 0
        jne c_edg
        
        push esi
        push ecx
        mov esi, OFFSET bulletArr
        mov ecx, MAX_BULLETS
    cw_b: mov [esi].Bullet.isActive, 0
          add esi, TYPE Bullet
          dec ecx
          jnz cw_b
          
        mov esi, OFFSET enemyBulletArr
        mov ecx, MAX_ENEMY_BULLETS
    cw_eb: mov [esi].Bullet.isActive, 0
           add esi, TYPE Bullet
           dec ecx
           jnz cw_eb
        pop ecx
        pop esi
        
        inc currentWave
        call InitWave
        jmp e_done
        
    c_edg:
        cmp edx, 1
        jne e_done
        neg enemyDir
    .ENDIF
e_done:
    ret
UpdateEnemies ENDP

; --- BOSS LOGIC ---
UpdateBoss PROC USES esi ecx ebx edi
    cmp bossActive, 0
    je end_b

    inc bossTimer

    .IF bossState == 6
        invoke RandomRange, 400
        add eax, 200
        mov ebx, eax
        invoke RandomRange, 150
        add eax, 20
        invoke SpawnExplosion, ebx, eax
        
        .IF bossTimer > 180
            mov gameState, STATE_WIN
        .ENDIF
        ret
    .ENDIF

    mov eax, frameCount
    and eax, 63     
    cmp eax, 0
    jne skp_mn
    invoke RandomRange, 700
    add eax, 50
    invoke SpawnEnemyBullet, eax, 140, 0, 9 
 skp_mn:

    .IF bossState == 0
        .IF bossTimer > 40
            invoke RandomRange, 5 
            inc eax               
            mov bossState, eax
            mov bossTimer, 0
            
            invoke RandomRange, 3     
            cmp eax, 0
            jne skip_shield
            mov bossShieldHP, 25
          skip_shield:

            .IF eax == 1
                mov bossLaserX, 400
            .ELSEIF eax == 3
                ; RED ATTACK SETUP: Safe X and Y boundaries
                invoke RandomRange, 650
                mov bossSafeX, eax
                invoke RandomRange, 250
                add eax, 250
                mov bossSafeY, eax
            .ELSEIF eax == 5
                ; PELLET SETUP: Constrained strictly on screen
                mov pelletX, 400
                mov pelletY, 150
                invoke RandomRange, 700
                add eax, 50
                mov targetPelletX, eax
                invoke RandomRange, 250
                add eax, 250
                mov targetPelletY, eax
                mov pelletActive, 1
                mov pelletBurstCount, 0
            .ENDIF
        .ENDIF

    .ELSEIF bossState == 1
        .IF bossTimer > 40 && bossTimer < 140
            mov eax, bossLaserDir
            imul eax, 12  
            add bossLaserX, eax
            .IF bossLaserX > 550
                mov bossLaserDir, -1
            .ELSEIF bossLaserX < 200
                mov bossLaserDir, 1
            .ENDIF
            
            mov eax, playerX
            add eax, PLAYER_WIDTH
            cmp eax, bossLaserX
            jl s1_sf
            mov eax, bossLaserX
            add eax, 60 
            cmp playerX, eax
            jg s1_sf
            dec playerHealth
            invoke SpawnExplosion, playerX, playerY
            .IF playerHealth <= 0
                mov gameState, STATE_DEAD
            .ENDIF
          s1_sf:
        .ELSEIF bossTimer >= 140
            mov bossState, 0
            mov bossTimer, 0
        .ENDIF

    .ELSEIF bossState == 2
        mov eax, bossTimer
        .IF eax == 20 || eax == 40 || eax == 60 || eax == 80
            mov ebx, 0 
          bw_lp:
            cmp ebx, 800
            jge end_bw
            
            mov edi, playerX
            sub edi, 25
            cmp ebx, edi
            jl fire_bw
            mov edi, playerX
            add edi, 65
            cmp ebx, edi
            jg fire_bw
            jmp nxt_bw
            
          fire_bw:
            invoke SpawnEnemyBullet, ebx, 150, 0, 10
          nxt_bw:
            add ebx, 40
            jmp bw_lp
          end_bw:
        .ELSEIF bossTimer >= 100
            mov bossState, 0
            mov bossTimer, 0
        .ENDIF

    .ELSEIF bossState == 3
        ; RED ATTACK LOGIC
        .IF bossTimer > 80 && bossTimer < 120
            mov eax, playerX
            mov ebx, bossSafeX
            .IF eax < ebx
                jmp kill_p3
            .ENDIF
            add eax, PLAYER_WIDTH
            add ebx, 150
            .IF eax > ebx
                jmp kill_p3
            .ENDIF
            
            mov eax, playerY
            mov ebx, bossSafeY
            .IF eax < ebx
                jmp kill_p3
            .ENDIF
            add eax, PLAYER_HEIGHT
            add ebx, 150
            .IF eax > ebx
                jmp kill_p3
            .ENDIF
            
            jmp safe_p3
            
        kill_p3:
            mov playerHealth, 0
            mov gameState, STATE_DEAD
            invoke SpawnExplosion, playerX, playerY
        safe_p3:
        .ELSEIF bossTimer >= 140
            mov bossState, 0
            mov bossTimer, 0
        .ENDIF

    .ELSEIF bossState == 4
        mov eax, bossTimer
        .IF eax == 10 || eax == 25 || eax == 40 || eax == 55 || eax == 70
            mov esi, OFFSET bossBeamArr
            mov ecx, MAX_BOSS_BEAMS
          f_bb:
            cmp [esi].BossBeam.isActive, 0
            je do_bb
            add esi, TYPE BossBeam
            dec ecx
            jnz f_bb
            jmp skp_bb
          do_bb:
            mov [esi].BossBeam.isActive, 1
            mov [esi].BossBeam.timer, 0
            mov edi, playerX
            mov [esi].BossBeam.posx, edi
          skp_bb:
        .ENDIF

        mov esi, OFFSET bossBeamArr
        mov ecx, MAX_BOSS_BEAMS
      u_bb_lp:
        cmp [esi].BossBeam.isActive, 0
        je u_bb_nx
        inc [esi].BossBeam.timer
        mov eax, [esi].BossBeam.timer
        .IF eax >= 20 && eax <= 30
            mov edi, playerX
            add edi, PLAYER_WIDTH
            cmp edi, [esi].BossBeam.posx
            jl sf_bb
            mov edi, [esi].BossBeam.posx
            add edi, 40
            cmp playerX, edi
            jg sf_bb
            
            dec playerHealth
            invoke SpawnExplosion, playerX, playerY
            .IF playerHealth <= 0
                mov gameState, STATE_DEAD
            .ENDIF
          sf_bb:
        .ELSEIF eax > 30
            mov [esi].BossBeam.isActive, 0
        .ENDIF
      u_bb_nx:
        add esi, TYPE BossBeam
        dec ecx
        jnz u_bb_lp

        .IF bossTimer >= 110
            mov bossState, 0
            mov bossTimer, 0
        .ENDIF

    .ELSEIF bossState == 5
        .IF pelletActive == 1
            mov eax, pelletX
            mov ebx, targetPelletX
            .IF eax < ebx
                add eax, 10
                .IF eax > ebx
                    mov eax, ebx
                .ENDIF
                mov pelletX, eax
            .ELSEIF eax > ebx
                sub eax, 10
                .IF eax < ebx
                    mov eax, ebx
                .ENDIF
                mov pelletX, eax
            .ENDIF
            
            mov eax, pelletY
            mov ebx, targetPelletY
            .IF eax < ebx
                add eax, 10
                .IF eax > ebx
                    mov eax, ebx
                .ENDIF
                mov pelletY, eax
            .ELSEIF eax > ebx
                sub eax, 10
                .IF eax < ebx
                    mov eax, ebx
                .ENDIF
                mov pelletY, eax
            .ENDIF
            
            mov eax, pelletX
            .IF eax == targetPelletX
                mov eax, pelletY
                .IF eax == targetPelletY
                    mov pelletActive, 0
                    invoke SpawnExplosion, pelletX, pelletY
                .ENDIF
            .ENDIF
        .ELSE
            mov eax, bossTimer
            and eax, 7 
            .IF eax == 0
                mov eax, pelletBurstCount
                .IF eax < 5
                    inc pelletBurstCount
                    invoke SpawnEnemyBullet, pelletX, pelletY, 0, -8
                    invoke SpawnEnemyBullet, pelletX, pelletY, 0, 8
                    invoke SpawnEnemyBullet, pelletX, pelletY, -8, 0
                    invoke SpawnEnemyBullet, pelletX, pelletY, 8, 0
                    invoke SpawnEnemyBullet, pelletX, pelletY, -6, -6
                    invoke SpawnEnemyBullet, pelletX, pelletY, 6, -6
                    invoke SpawnEnemyBullet, pelletX, pelletY, -6, 6
                    invoke SpawnEnemyBullet, pelletX, pelletY, 6, 6
                .ENDIF
            .ENDIF
        .ENDIF
        
        .IF bossTimer >= 180
            mov bossState, 0
            mov bossTimer, 0
        .ENDIF
    .ENDIF

end_b:
    ret
UpdateBoss ENDP

; --- Collisions ---
CheckCollisions PROC USES esi edi ebx
    mov esi, OFFSET bulletArr
    mov ecx, MAX_BULLETS
cb_lp:
    cmp [esi].Bullet.isActive, 0
    je nx_pb

    .IF bossActive == 1 && bossState != 6
        .IF [esi].Bullet.posy < 165
            .IF [esi].Bullet.posx > 140 && [esi].Bullet.posx < 660
                .IF bossShieldHP > 0
                    dec bossShieldHP
                    mov [esi].Bullet.isActive, 0
                    invoke SpawnEnemyBullet, [esi].Bullet.posx, [esi].Bullet.posy, 0, 15 
                    invoke SpawnExplosion, [esi].Bullet.posx, [esi].Bullet.posy
                    jmp nx_pb
                .ELSE
                    mov [esi].Bullet.isActive, 0
                    dec bossHP
                    invoke SpawnExplosion, [esi].Bullet.posx, [esi].Bullet.posy
                    .IF bossHP <= 0
                        mov bossState, 6 
                        mov bossTimer, 0
                        push esi
                        push ecx
                        mov esi, OFFSET bossBeamArr
                        mov ecx, MAX_BOSS_BEAMS
                      clr_bb2: 
                        mov [esi].BossBeam.isActive, 0
                        add esi, TYPE BossBeam
                        dec ecx
                        jnz clr_bb2
                        pop ecx
                        pop esi
                    .ENDIF
                    jmp nx_pb
                .ENDIF
            .ENDIF
        .ENDIF
    .ENDIF

    push ecx
    mov edi, OFFSET enemyArr
    mov ecx, MAX_ENEMIES
ce_lp:
    cmp [edi].Enemy.isActive, 0
    je nx_pe
    mov eax, [esi].Bullet.posx
    add eax, BULLET_WIDTH
    cmp eax, [edi].Enemy.posx
    jl nx_pe
    mov eax, [esi].Bullet.posx
    mov ebx, [edi].Enemy.posx
    add ebx, ENEMY_WIDTH
    cmp eax, ebx
    jg nx_pe
    mov eax, [esi].Bullet.posy
    add eax, BULLET_HEIGHT
    cmp eax, [edi].Enemy.posy
    jl nx_pe
    mov eax, [esi].Bullet.posy
    mov ebx, [edi].Enemy.posy
    add ebx, ENEMY_HEIGHT
    cmp eax, ebx
    jg nx_pe

    mov [esi].Bullet.isActive, 0
    dec [edi].Enemy.health
    cmp [edi].Enemy.health, 0
    jg dn_e 

    mov [edi].Enemy.isActive, 0
    invoke SpawnExplosion, [edi].Enemy.posx, [edi].Enemy.posy
    
    invoke RandomRange, 30
    cmp eax, 0
    jne try_health
    invoke SpawnPowerUp, [edi].Enemy.posx, [edi].Enemy.posy, 0
    jmp dn_e
  try_health:
    cmp healthDropsInWave, 2
    jge dn_e
    invoke RandomRange, 8
    cmp eax, 0
    jne dn_e
    inc healthDropsInWave
    invoke SpawnPowerUp, [edi].Enemy.posx, [edi].Enemy.posy, 1
    jmp dn_e 
nx_pe:
    add edi, TYPE Enemy
    dec ecx
    jnz ce_lp
dn_e:
    pop ecx

nx_pb:
    add esi, TYPE Bullet
    dec ecx
    jnz cb_lp

    mov edi, OFFSET enemyArr
    mov ecx, MAX_ENEMIES
p_vs_e:
    cmp [edi].Enemy.isActive, 0
    je nx_p_e
    
    mov eax, playerX
    add eax, PLAYER_WIDTH
    cmp eax, [edi].Enemy.posx
    jl nx_p_e
    mov eax, playerX
    mov ebx, [edi].Enemy.posx
    add ebx, ENEMY_WIDTH
    cmp eax, ebx
    jg nx_p_e
    mov eax, playerY
    add eax, PLAYER_HEIGHT
    cmp eax, [edi].Enemy.posy
    jl nx_p_e
    mov eax, playerY
    mov ebx, [edi].Enemy.posy
    add ebx, ENEMY_HEIGHT
    cmp eax, ebx
    jg nx_p_e
    
    mov playerHealth, 0
    mov gameState, STATE_DEAD
    invoke SpawnExplosion, playerX, playerY
    jmp e_p_vs_e 
nx_p_e:
    add edi, TYPE Enemy
    dec ecx
    jnz p_vs_e
e_p_vs_e:

    mov esi, OFFSET enemyBulletArr
    mov ecx, MAX_ENEMY_BULLETS
eb_lp:
    cmp [esi].Bullet.isActive, 0
    je nx_eb
    mov eax, [esi].Bullet.posx
    add eax, ENEMY_BULLET_W
    cmp eax, playerX
    jl nx_eb
    mov eax, [esi].Bullet.posx
    mov ebx, playerX
    add ebx, PLAYER_WIDTH
    cmp eax, ebx
    jg nx_eb
    mov eax, [esi].Bullet.posy
    add eax, ENEMY_BULLET_H
    cmp eax, playerY
    jl nx_eb
    mov eax, [esi].Bullet.posy
    mov ebx, playerY
    add ebx, PLAYER_HEIGHT
    cmp eax, ebx
    jg nx_eb

    mov [esi].Bullet.isActive, 0
    invoke SpawnExplosion, playerX, playerY
    dec playerHealth
    .IF playerHealth <= 0
        mov gameState, STATE_DEAD
    .ENDIF
nx_eb:
    add esi, TYPE Bullet
    dec ecx
    jnz eb_lp
    ret
CheckCollisions ENDP

; --- Main Loop Routine ---
UpdateGame PROC
    inc frameCount
    
    mov esi, OFFSET starArr
    mov ecx, MAX_STARS
us_lp:
    mov eax, [esi].Star.speed
    add [esi].Star.posy, eax
    cmp [esi].Star.posy, SCREEN_HEIGHT
    jl us_skp
    mov [esi].Star.posy, 0
    push ecx
    invoke RandomRange, SCREEN_WIDTH
    pop ecx
    mov [esi].Star.posx, eax
us_skp:
    add esi, TYPE Star
    dec ecx
    jnz us_lp

    mov esi, OFFSET explosionArr
    mov ecx, MAX_EXPLOSIONS
ue_lp:
    cmp [esi].Explosion.isActive, 0
    je ue_skp
    dec [esi].Explosion.timer
    cmp [esi].Explosion.timer, 0
    jg ue_skp
    mov [esi].Explosion.isActive, 0
ue_skp:
    add esi, TYPE Explosion
    dec ecx
    jnz ue_lp

    mov esi, OFFSET powerupArr
    mov ecx, MAX_POWERUPS
up_lp:
    cmp [esi].PowerUp.isActive, 0
    je up_nxt
    add [esi].PowerUp.posy, POWERUP_SPEED
    cmp [esi].PowerUp.posy, SCREEN_HEIGHT
    jg k_pu
    cmp gameState, STATE_PLAY
    jne up_nxt
    
    mov eax, [esi].PowerUp.posx
    add eax, POWERUP_SIZE
    cmp eax, playerX
    jl up_nxt
    mov eax, [esi].PowerUp.posx
    mov ebx, playerX
    add ebx, PLAYER_WIDTH
    cmp eax, ebx
    jg up_nxt
    mov eax, [esi].PowerUp.posy
    add eax, POWERUP_SIZE
    cmp eax, playerY
    jl up_nxt
    mov eax, [esi].PowerUp.posy
    mov ebx, playerY
    add ebx, PLAYER_HEIGHT
    cmp eax, ebx
    jg up_nxt
    
    mov [esi].PowerUp.isActive, 0
    mov eax, [esi].PowerUp.puType
    .IF eax == 1
        .IF playerHealth < 5
            inc playerHealth
        .ENDIF
    .ELSE
        .IF weaponLevel < 3
            inc weaponLevel
        .ENDIF
    .ENDIF
    jmp up_nxt
k_pu: mov [esi].PowerUp.isActive, 0
up_nxt:
    add esi, TYPE PowerUp
    dec ecx
    jnz up_lp

    .IF gameState == STATE_TITLE
        invoke GetAsyncKeyState, VK_RETURN
        test eax, 8000h
        jz g_end
        mov gameState, STATE_PLAY
        jmp g_end
    .ENDIF

    cmp gameState, STATE_PLAY
    jne g_end
    
    call UpdatePlayer
    call UpdateBullets
    call UpdateEnemies
    call UpdateBoss
    call CheckCollisions

g_end:
    ret
UpdateGame ENDP

; --- Rendering Base ---
RenderGame PROC USES esi hdc:DWORD
    LOCAL animT:DWORD
    LOCAL rcT:RECT
    LOCAL tHeight:DWORD
    LOCAL tColor:DWORD
    LOCAL eColor:DWORD

    mov eax, frameCount
    shr eax, 4 
    and eax, 1
    mov animT, eax

    .IF gameState != STATE_TITLE
        mov esi, OFFSET starArr
        mov ecx, MAX_STARS
    rs_lp:
        push ecx
        invoke DrawRect, hdc, [esi].Star.posx, [esi].Star.posy, [esi].Star.starSize, [esi].Star.starSize, [esi].Star.color
        pop ecx
        add esi, TYPE Star
        dec ecx
        jnz rs_lp
    .ENDIF

    .IF gameState != STATE_TITLE
        .IF gameState != STATE_DEAD
            ; --- Player Spaceship Design ---
            mov eax, playerX
            add eax, 17
            invoke DrawRect, hdc, eax, playerY, 6, 4, COLOR_WHITE
            
            ; Main Body
            mov eax, playerX
            add eax, 15
            mov ebx, playerY
            add ebx, 4
            invoke DrawRect, hdc, eax, ebx, 10, 16, COLOR_BLUE
            
            ; Wings
            mov eax, playerY
            add eax, 12
            invoke DrawRect, hdc, playerX, eax, 15, 8, COLOR_DARKGRAY
            mov eax, playerX
            add eax, 25
            mov ebx, playerY
            add ebx, 12
            invoke DrawRect, hdc, eax, ebx, 15, 8, COLOR_DARKGRAY
            
            ; Cockpit
            mov eax, playerX
            add eax, 18
            mov ebx, playerY
            add ebx, 6
            invoke DrawRect, hdc, eax, ebx, 4, 4, COLOR_CYAN

            ; --- Thruster Animation ---
            mov tHeight, 5
            mov tColor, COLOR_ORANGE
            
            ; Flame Flickering
            mov eax, frameCount
            and eax, 3
            add tHeight, eax
            
            ; Movement Response
            invoke GetAsyncKeyState, VK_UP
            test eax, 8000h
            jz check_flames_side
            add tHeight, 10 ; Boost flames when moving up
            mov tColor, COLOR_YELLOW
            
        check_flames_side:
            ; Left Thruster
            mov eax, playerX
            add eax, 4
            mov ebx, playerY
            add ebx, 20
            invoke DrawRect, hdc, eax, ebx, 7, tHeight, tColor
            
            ; Right Thruster
            mov eax, playerX
            add eax, 29
            mov ebx, playerY
            add ebx, 20
            invoke DrawRect, hdc, eax, ebx, 7, tHeight, tColor
            
            ; HUD: Health
            mov ebx, 10
            mov ecx, playerHealth
            cmp ecx, 0
            jle r_h_d
        rh_lp:
            push ecx
            invoke DrawRect, hdc, ebx, 10, 15, 10, COLOR_BLUE
            add ebx, 20
            pop ecx
            dec ecx
            jnz rh_lp
        r_h_d:
        .ENDIF

        mov esi, OFFSET bulletArr
        mov ecx, MAX_BULLETS
    rb_lp:
        cmp [esi].Bullet.isActive, 0
        je rb_nx
        push ecx
        invoke DrawRect, hdc, [esi].Bullet.posx, [esi].Bullet.posy, BULLET_WIDTH, BULLET_HEIGHT, COLOR_YELLOW
        pop ecx
    rb_nx:
        add esi, TYPE Bullet
        dec ecx
        jnz rb_lp

        mov esi, OFFSET enemyBulletArr
        mov ecx, MAX_ENEMY_BULLETS
    reb_lp:
        cmp [esi].Bullet.isActive, 0
        je reb_nx
        push ecx
        invoke DrawRect, hdc, [esi].Bullet.posx, [esi].Bullet.posy, ENEMY_BULLET_W, ENEMY_BULLET_H, COLOR_MAGENTA
        pop ecx
    reb_nx:
        add esi, TYPE Bullet
        dec ecx
        jnz reb_lp

        mov esi, OFFSET powerupArr
        mov ecx, MAX_POWERUPS
    rpu_lp:
        cmp [esi].PowerUp.isActive, 0
        je rpu_nx
        push ecx
        mov eax, [esi].PowerUp.puType
        .IF eax == 1 ; Health
            invoke DrawRect, hdc, [esi].PowerUp.posx, [esi].PowerUp.posy, POWERUP_SIZE, POWERUP_SIZE, COLOR_RED
            mov eax, [esi].PowerUp.posx
            add eax, 4
            mov ebx, [esi].PowerUp.posy
            add ebx, 2
            invoke DrawRect, hdc, eax, ebx, 4, 8, COLOR_WHITE
            mov eax, [esi].PowerUp.posx
            add eax, 2
            mov ebx, [esi].PowerUp.posy
            add ebx, 4
            invoke DrawRect, hdc, eax, ebx, 8, 4, COLOR_WHITE
        .ELSE
            invoke DrawRect, hdc, [esi].PowerUp.posx, [esi].PowerUp.posy, POWERUP_SIZE, POWERUP_SIZE, COLOR_CYAN
        .ENDIF
        pop ecx
    rpu_nx:
        add esi, TYPE PowerUp
        dec ecx
        jnz rpu_lp

        mov esi, OFFSET enemyArr
        mov ecx, MAX_ENEMIES
    re_lp:
        cmp [esi].Enemy.isActive, 0
        je re_nx
        push ecx
        .IF [esi].Enemy.health > 6
            mov eax, COLOR_MAGENTA
        .ELSEIF [esi].Enemy.health > 4
            mov eax, COLOR_RED
        .ELSEIF [esi].Enemy.health > 2
            mov eax, COLOR_ORANGE
        .ELSE
            mov eax, COLOR_GREEN
        .ENDIF
        mov eColor, eax

        ; --- Alien Enemy Design ---
        ; Central Body
        mov eax, [esi].Enemy.posx
        add eax, 5
        mov ebx, [esi].Enemy.posy
        add ebx, 5
        invoke DrawRect, hdc, eax, ebx, 20, 10, eColor
        
        ; Head
        mov eax, [esi].Enemy.posx
        add eax, 10
        invoke DrawRect, hdc, eax, [esi].Enemy.posy, 10, 5, eColor
        
        ; Fins
        mov eax, [esi].Enemy.posx
        mov ebx, [esi].Enemy.posy
        add ebx, 8
        invoke DrawRect, hdc, eax, ebx, 5, 10, COLOR_DARKGRAY
        mov eax, [esi].Enemy.posx
        add eax, 25
        mov ebx, [esi].Enemy.posy
        add ebx, 8
        invoke DrawRect, hdc, eax, ebx, 5, 10, COLOR_DARKGRAY
        
        ; Glowing Eyes
        mov eax, [esi].Enemy.posx
        add eax, 12
        mov ebx, [esi].Enemy.posy
        add ebx, 3
        invoke DrawRect, hdc, eax, ebx, 2, 2, COLOR_YELLOW
        mov eax, [esi].Enemy.posx
        add eax, 17
        mov ebx, [esi].Enemy.posy
        add ebx, 3
        invoke DrawRect, hdc, eax, ebx, 2, 2, COLOR_YELLOW

        pop ecx
    re_nx:
        add esi, TYPE Enemy
        dec ecx
        jnz re_lp

        .IF bossActive == 1 && bossState != 6
            cmp bossHP, 0
            jle skp_bar
            invoke DrawRect, hdc, 0, 0, bossHP, 8, COLOR_RED
          skp_bar:

            mov edx, COLOR_DARKGRAY
            mov ebx, COLOR_DARKGRAY
            .IF bossState == 1
                mov ebx, COLOR_ORANGE  
            .ELSEIF bossState == 2
                mov edx, COLOR_MAGENTA 
            .ELSEIF bossState == 3
                mov ebx, COLOR_DARKRED
                mov edx, COLOR_DARKRED
            .ELSEIF bossState == 4
                mov ebx, COLOR_CYAN
                mov edx, COLOR_CYAN
            .ELSEIF bossState == 5
                mov ebx, COLOR_YELLOW
                mov edx, COLOR_YELLOW
            .ENDIF

            invoke DrawRect, hdc, 200, 20, 400, 80, edx
            invoke DrawRect, hdc, 150, 40, 50, 110, ebx
            invoke DrawRect, hdc, 600, 40, 50, 110, ebx
            
            mov eax, COLOR_BLUE
            .IF bossState == 1
                mov eax, COLOR_ORANGE
            .ELSEIF bossState == 2
                mov eax, COLOR_MAGENTA
            .ELSEIF bossState == 3
                mov eax, COLOR_RED
            .ELSEIF bossState == 4
                mov eax, COLOR_CYAN
            .ELSEIF bossState == 5
                mov eax, COLOR_YELLOW
            .ENDIF

            .IF animT == 0
                invoke DrawRect, hdc, 360, 60, 80, 40, eax
            .ELSE
                invoke DrawRect, hdc, 360, 60, 80, 40, COLOR_WHITE
            .ENDIF

            .IF bossShieldHP > 0
                mov eax, bossShieldHP
                shl eax, 4          
                mov ebx, eax
                shr ebx, 1
                mov ecx, 400
                sub ecx, ebx        
                
                push ecx
                push eax
                invoke DrawRect, hdc, ecx, 155, eax, 8, COLOR_CYAN
                pop eax
                pop ecx
                
                add ecx, 5
                .IF eax > 10
                    sub eax, 10
                    invoke DrawRect, hdc, ecx, 157, eax, 4, COLOR_WHITE
                .ENDIF
            .ENDIF

            .IF bossState == 1
                .IF bossTimer <= 40
                    invoke DrawRect, hdc, bossLaserX, 100, 60, 600, COLOR_DARKRED
                .ELSE
                    invoke DrawRect, hdc, bossLaserX, 100, 60, 600, COLOR_RED
                    mov eax, bossLaserX
                    add eax, 15
                    invoke DrawRect, hdc, eax, 100, 30, 600, COLOR_YELLOW
                .ENDIF
            .ELSEIF bossState == 3
                .IF bossTimer <= 80
                    mov eax, bossSafeY
                    sub eax, 150
                    invoke DrawRect, hdc, 0, 150, 800, eax, COLOR_DARKRED
                    
                    mov eax, bossSafeY
                    add eax, 150
                    mov ebx, 600
                    sub ebx, eax
                    invoke DrawRect, hdc, 0, eax, 800, ebx, COLOR_DARKRED
                    
                    invoke DrawRect, hdc, 0, bossSafeY, bossSafeX, 150, COLOR_DARKRED
                    
                    mov eax, bossSafeX
                    add eax, 150
                    mov ebx, 800
                    sub ebx, eax
                    invoke DrawRect, hdc, eax, bossSafeY, ebx, 150, COLOR_DARKRED
                .ELSE
                    mov eax, bossSafeY
                    sub eax, 150
                    invoke DrawRect, hdc, 0, 150, 800, eax, COLOR_RED
                    .IF eax > 20
                        sub eax, 20
                        invoke DrawRect, hdc, 10, 160, 780, eax, COLOR_WHITE
                    .ENDIF
                    
                    mov eax, bossSafeY
                    add eax, 150
                    mov ebx, 600
                    sub ebx, eax
                    push eax
                    push ebx
                    invoke DrawRect, hdc, 0, eax, 800, ebx, COLOR_RED
                    pop ebx
                    pop eax
                    .IF ebx > 20
                        sub ebx, 20
                        mov ecx, eax
                        add ecx, 10
                        invoke DrawRect, hdc, 10, ecx, 780, ebx, COLOR_WHITE
                    .ENDIF
                    
                    invoke DrawRect, hdc, 0, bossSafeY, bossSafeX, 150, COLOR_RED
                    mov eax, bossSafeX
                    .IF eax > 20
                        sub eax, 20
                        mov ebx, bossSafeY
                        add ebx, 10
                        invoke DrawRect, hdc, 10, ebx, eax, 130, COLOR_WHITE
                    .ENDIF
                    
                    mov eax, bossSafeX
                    add eax, 150
                    mov ebx, 800
                    sub ebx, eax
                    push eax
                    push ebx
                    invoke DrawRect, hdc, eax, bossSafeY, ebx, 150, COLOR_RED
                    pop ebx
                    pop eax
                    .IF ebx > 20
                        mov ecx, eax
                        add ecx, 10
                        sub ebx, 20
                        mov edx, bossSafeY
                        add edx, 10
                        invoke DrawRect, hdc, ecx, edx, ebx, 130, COLOR_WHITE
                    .ENDIF
                .ENDIF
            .ELSEIF bossState == 5
                .IF pelletActive == 1
                    .IF animT == 0
                        invoke DrawRect, hdc, pelletX, pelletY, 20, 20, COLOR_MAGENTA
                    .ELSE
                        invoke DrawRect, hdc, pelletX, pelletY, 20, 20, COLOR_WHITE
                    .ENDIF
                .ENDIF
            .ENDIF
            
            mov esi, OFFSET bossBeamArr
            mov ecx, MAX_BOSS_BEAMS
          r_bb_lp:
            cmp [esi].BossBeam.isActive, 0
            je r_bb_nx
            push ecx
            mov eax, [esi].BossBeam.timer
            .IF eax < 20
                mov ebx, [esi].BossBeam.posx
                add ebx, 18
                invoke DrawRect, hdc, ebx, 100, 4, 600, COLOR_CYAN
            .ELSEIF eax <= 30
                mov ebx, [esi].BossBeam.posx
                invoke DrawRect, hdc, ebx, 100, 40, 600, COLOR_WHITE
                add ebx, 10
                invoke DrawRect, hdc, ebx, 100, 20, 600, COLOR_CYAN
            .ENDIF
            pop ecx
          r_bb_nx:
            add esi, TYPE BossBeam
            dec ecx
            jnz r_bb_lp
        .ENDIF
    .ENDIF

    .IF gameState != STATE_TITLE
        mov esi, OFFSET explosionArr
        mov ecx, MAX_EXPLOSIONS
    rx_lp:
        cmp [esi].Explosion.isActive, 0
        je rx_nx
        push ecx
        .IF [esi].Explosion.timer > 10
            mov eax, [esi].Explosion.posx
            sub eax, 5
            mov ebx, [esi].Explosion.posy
            sub ebx, 5
            invoke DrawRect, hdc, eax, ebx, 30, 30, COLOR_YELLOW
        .ELSEIF [esi].Explosion.timer > 5
            invoke DrawRect, hdc, [esi].Explosion.posx, [esi].Explosion.posy, 20, 20, COLOR_ORANGE
        .ELSE
            mov eax, [esi].Explosion.posx
            add eax, 5
            mov ebx, [esi].Explosion.posy
            add ebx, 5
            invoke DrawRect, hdc, eax, ebx, 10, 10, COLOR_RED
        .ENDIF
        pop ecx
    rx_nx:
        add esi, TYPE Explosion
        dec ecx
        jnz rx_lp
    .ENDIF

    .IF gameState != STATE_PLAY
        invoke SetBkMode, hdc, TRANSPARENT
        mov rcT.left, 0
        mov rcT.right, SCREEN_WIDTH
        
        .IF gameState == STATE_TITLE
            ; --- Background ---
            invoke DrawRect, hdc, 600, 480, 120, 80, COLOR_DARKGRAY
            invoke DrawRect, hdc, 580, 500, 160, 40, COLOR_DARKGRAY
            invoke DrawRect, hdc, 620, 460, 80, 100, COLOR_DARKGRAY
            
            ; Moon Craters
            invoke DrawRect, hdc, 630, 490, 15, 10, COLOR_LIGHTGRAY
            invoke DrawRect, hdc, 670, 520, 10, 10, COLOR_LIGHTGRAY
            invoke DrawRect, hdc, 610, 510, 20, 15, COLOR_LIGHTGRAY
            
            ; Sun
            invoke DrawRect, hdc, 45, 45, 40, 40, COLOR_YELLOW
            invoke DrawRect, hdc, 55, 55, 20, 20, COLOR_WHITE
            
            ; Cyan Stars
            invoke DrawRect, hdc, 200, 150, 3, 3, COLOR_CYAN
            invoke DrawRect, hdc, 150, 400, 3, 3, COLOR_CYAN
            invoke DrawRect, hdc, 400, 50, 3, 3, COLOR_CYAN
            invoke DrawRect, hdc, 700, 200, 3, 3, COLOR_CYAN
            invoke DrawRect, hdc, 550, 100, 3, 3, COLOR_CYAN
            invoke DrawRect, hdc, 320, 450, 2, 2, COLOR_CYAN
            invoke DrawRect, hdc, 680, 50, 2, 2, COLOR_CYAN
            invoke DrawRect, hdc, 100, 280, 2, 2, COLOR_CYAN
            
            ; White Stars
            invoke DrawRect, hdc, 50, 450, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 250, 500, 1, 1, COLOR_WHITE
            invoke DrawRect, hdc, 750, 550, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 400, 300, 1, 1, COLOR_WHITE
            invoke DrawRect, hdc, 600, 150, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 120, 50, 1, 1, COLOR_WHITE
            invoke DrawRect, hdc, 30, 200, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 770, 300, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 10, 580, 2, 2, COLOR_WHITE
            invoke DrawRect, hdc, 450, 580, 2, 2, COLOR_WHITE
            
            ; Yellow Stars
            invoke DrawRect, hdc, 300, 80, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 100, 550, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 650, 400, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 720, 100, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 350, 520, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 10, 10, 1, 1, COLOR_YELLOW
            invoke DrawRect, hdc, 790, 10, 1, 1, COLOR_YELLOW

            ; Spaceship
            invoke DrawRect, hdc, 175, 120, 50, 20, COLOR_BLUE     
            invoke DrawRect, hdc, 150, 130, 100, 10, COLOR_DARKGRAY 
            invoke DrawRect, hdc, 195, 115, 10, 10, COLOR_WHITE     
            invoke DrawRect, hdc, 198, 125, 4, 4, COLOR_CYAN      
            invoke DrawRect, hdc, 160, 140, 10, 8, COLOR_ORANGE  
            invoke DrawRect, hdc, 230, 140, 10, 8, COLOR_ORANGE  

            ; Nebula Band Streaks
            invoke DrawRect, hdc, 0, 100, 800, 5, COLOR_DARKGRAY
            invoke DrawRect, hdc, 0, 350, 800, 8, COLOR_DARKRED
            invoke DrawRect, hdc, 0, 500, 800, 4, COLOR_DARKGRAY

            invoke SetTextColor, hdc, COLOR_YELLOW
            mov rcT.top, 150
            mov rcT.bottom, 200
            invoke DrawTextA, hdc, ADDR szTitle, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
            
            invoke SetTextColor, hdc, COLOR_WHITE
            mov rcT.top, 250
            mov rcT.bottom, 280
            invoke DrawTextA, hdc, ADDR szControls1, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
            
            mov rcT.top, 290
            mov rcT.bottom, 320
            invoke DrawTextA, hdc, ADDR szControls2, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
            
            invoke SetTextColor, hdc, COLOR_GREEN
            mov rcT.top, 400
            mov rcT.bottom, 450
            invoke DrawTextA, hdc, ADDR szStartMsg, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        .ELSEIF gameState == STATE_DEAD
            mov rcT.top, 250
            mov rcT.bottom, 300
            invoke SetTextColor, hdc, COLOR_RED
            invoke DrawTextA, hdc, ADDR szGameOver, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        .ELSEIF gameState == STATE_WIN
            mov rcT.top, 250
            mov rcT.bottom, 300
            invoke SetTextColor, hdc, COLOR_GREEN
            invoke DrawTextA, hdc, ADDR szWin, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        .ENDIF
        
        .IF gameState != STATE_TITLE
            invoke SetTextColor, hdc, COLOR_WHITE
            mov rcT.top, 290
            mov rcT.bottom, 340
            invoke DrawTextA, hdc, ADDR szRestart, -1, ADDR rcT, DT_CENTER or DT_VCENTER or DT_SINGLELINE
        .ENDIF
    .ENDIF
    ret
RenderGame ENDP

; --- Core Win32 ---
RestartGame PROC USES esi ecx
    mov playerHealth, 3
    mov weaponLevel, 1
    mov playerX, 380
    mov playerY, 530
    mov gameState, STATE_PLAY
    mov shootCooldown, 0
    mov currentWave, 1
    mov bossActive, 0
    
    mov esi, OFFSET bulletArr
    mov ecx, MAX_BULLETS
clr_b: mov [esi].Bullet.isActive, 0
       add esi, TYPE Bullet
       dec ecx
       jnz clr_b

    mov esi, OFFSET enemyBulletArr
    mov ecx, MAX_ENEMY_BULLETS
clr_eb: mov [esi].Bullet.isActive, 0
        add esi, TYPE Bullet
        dec ecx
        jnz clr_eb

    mov esi, OFFSET explosionArr
    mov ecx, MAX_EXPLOSIONS
clr_x: mov [esi].Explosion.isActive, 0
       add esi, TYPE Explosion
       dec ecx
       jnz clr_x

    mov esi, OFFSET bossBeamArr
    mov ecx, MAX_BOSS_BEAMS
clr_bb: mov [esi].BossBeam.isActive, 0
        add esi, TYPE BossBeam
        dec ecx
        jnz clr_bb

    call InitWave
    ret
RestartGame ENDP

WndProc PROC hwnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL hdc:DWORD, ps:PAINTSTRUCT, mDC:DWORD, mBm:DWORD, oBm:DWORD
    .IF uMsg == WM_DESTROY
        invoke KillTimer, hwnd, 1
        invoke PostQuitMessage, 0
    .ELSEIF uMsg == WM_ERASEBKGND
        mov eax, 1
        ret
    .ELSEIF uMsg == WM_TIMER
        call UpdateGame
        invoke InvalidateRect, hwnd, NULL, FALSE
    .ELSEIF uMsg == WM_PAINT
        invoke BeginPaint, hwnd, ADDR ps
        mov hdc, eax
        invoke CreateCompatibleDC, hdc
        mov mDC, eax
        invoke CreateCompatibleBitmap, hdc, SCREEN_WIDTH, SCREEN_HEIGHT
        mov mBm, eax
        invoke SelectObject, mDC, mBm
        mov oBm, eax

        invoke DrawRect, mDC, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, COLOR_BLACK
        invoke RenderGame, mDC

        invoke BitBlt, hdc, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, mDC, 0, 0, SRCCOPY
        invoke SelectObject, mDC, oBm
        invoke DeleteObject, mBm
        invoke DeleteDC, mDC
        invoke EndPaint, hwnd, ADDR ps
    .ELSEIF uMsg == WM_KEYDOWN
        .IF wParam == VK_ESCAPE
            invoke DestroyWindow, hwnd
        .ELSEIF wParam == 'R'
            .IF gameState != STATE_PLAY
                call RestartGame
            .ENDIF
        .ELSEIF wParam == 'P'
            .IF gameState == STATE_PLAY
                mov eax, playerY
                sub eax, 40
                invoke SpawnPowerUp, playerX, eax, 0
            .ENDIF
        .ELSEIF wParam == 'B'
            .IF gameState == STATE_PLAY && currentWave < 4
                mov currentWave, 4
                
                push esi
                push ecx
                mov esi, OFFSET enemyArr
                mov ecx, MAX_ENEMIES
            clr_e_cheat: 
                mov [esi].Enemy.isActive, 0
                add esi, TYPE Enemy
                dec ecx
                jnz clr_e_cheat
                pop ecx
                pop esi
                
                call InitWave
            .ENDIF
        .ENDIF
    .ELSE
        invoke DefWindowProc, hwnd, uMsg, wParam, lParam
        ret
    .ENDIF
    xor eax, eax
    ret
WndProc ENDP

WinMain PROC hInst:DWORD, hPrevInst:DWORD, cmdLine:DWORD, cmdShow:DWORD
    LOCAL wc:WNDCLASSEX, msg:MSG, hwnd:DWORD
    
    invoke GetTickCount
    mov randSeed, eax
    
    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInst
    mov wc.hInstance, eax
    mov wc.hbrBackground, COLOR_WINDOW+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName
    
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    
    invoke RegisterClassEx, ADDR wc
    invoke CreateWindowEx, 0, ADDR ClassName, ADDR AppName, WS_OVERLAPPEDWINDOW, 100, 100, SCREEN_WIDTH, SCREEN_HEIGHT, NULL, NULL, hInst, NULL
    mov hwnd, eax
    
    invoke SetTimer, hwnd, 1, 16, NULL
    invoke ShowWindow, hwnd, SW_SHOWNORMAL
    invoke UpdateWindow, hwnd
    
    mov esi, OFFSET starArr
    mov ecx, MAX_STARS
i_st: push ecx
      invoke RandomRange, SCREEN_WIDTH
      mov [esi].Star.posx, eax
      invoke RandomRange, SCREEN_HEIGHT
      mov [esi].Star.posy, eax
      invoke RandomRange, 3
      .IF eax == 0
          mov [esi].Star.speed, 2
          mov [esi].Star.starSize, 2
          mov [esi].Star.color, COLOR_DARKGRAY
      .ELSEIF eax == 1
          mov [esi].Star.speed, 4
          mov [esi].Star.starSize, 2
          mov [esi].Star.color, COLOR_LIGHTGRAY
      .ELSE
          mov [esi].Star.speed, 8
          mov [esi].Star.starSize, 3
          mov [esi].Star.color, COLOR_WHITE
      .ENDIF
      pop ecx
      add esi, TYPE Star
      dec ecx
      jnz i_st

    call InitWave

ml: invoke GetMessage, ADDR msg, NULL, 0, 0
    cmp eax, 0
    je ex
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp ml
    
ex: mov eax, msg.wParam
    ret
WinMain ENDP

start:
    invoke GetModuleHandle, NULL
    invoke WinMain, eax, NULL, NULL, SW_SHOWDEFAULT
    invoke ExitProcess, eax
END start