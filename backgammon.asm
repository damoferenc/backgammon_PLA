;; Damo Ferenc
;; grupa 10
; jocul table cu doi jucatori
; jucatorul cu piese albe este primul
.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Backgammon",0
area_width EQU 960
area_height EQU 600
area DD 0

t dd 24 dup(0)
col dd 24 dup(0); 1= white; 2=black; 0=none
green dd 24 dup(0)
flux dd 0
zar1 dd 0
zar2 dd 0
cinci dd 5
err dd 0
pos dd 0 ; pozitia curenta
player dd 1; 1-white, 2-black
selected dd 0
reput1 dd 0 ;primul jucator are piese scoase
reput2 dd 0 ;al doilea jucator are piese scoase
scoatere_din_casa_player_1 dd 0 ;este 1 daca primul jucator a inceput sa ia piesele din casa
scoatere_din_casa_player_2 dd 0 ;este 1 daca al doilea jucator a inceput sa ia piesele din casa
housegreen1 dd 0
housegreen2 dd 0



counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc
include simbol.inc
include zaruri.inc

.code

check_if_all_in_house_player2 macro
local yes, endhouse
	mov ebx, 0
	mov eax, 0
	add eax, [t]
	add eax, [t+4]
	add eax, [t+4*2]
	add eax, [t+4*3]
	add eax, [t+4*4]
	add eax, [t+4*5]
	cmp eax, 15
	je yes
	jmp endhouse
	yes:
	mov ebx, 1
	endhouse:
endm

check_if_all_in_house_player1 macro
local yes2, endhouse2
	mov ebx, 0
	mov eax, 0
	add eax, [t+4*19]
	add eax, [t+4*20]
	add eax, [t+4*21]
	add eax, [t+4*22]
	add eax, [t+4*23]
	add eax, [t+4*18]
	cmp eax, 15
	je yes2
	jmp endhouse2
	yes2:
	mov ebx, 1
	endhouse2:
endm

make_dice proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	lea esi, dice
	sub eax, '0'
	
draw_text:
	mov ebx, 40
	mul ebx
	mov ebx, 40
	mul ebx
	add esi, eax
	mov ecx, 40
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, 40
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, 40
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 1
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_dice endp

; un macro ca sa apelam mai usor desenarea simbolului
make_dice_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_dice
	add esp, 16
endm

; procedura make_symbol afiseaza un simbol
; arg1 - culoarea
; arg2 - culoarea backgroundului
; arg3 - pos_x
; arg4 - pos_y
make_symbol proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, 0
	lea esi, simbol	
	
draw_text:
	mov ebx, symbol_height
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, area
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_height
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	push eax
	mov eax, [ebp+arg1]
	mov dword ptr [edi], eax
	pop eax
	jmp simbol_pixel_next
simbol_pixel_alb:
	push eax
	mov eax, [ebp+arg2]
	mov dword ptr [edi], eax
	pop eax
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_symbol endp

; un macro ca sa apelam mai usor desenarea simbolului
make_symbol_macro macro color, colorbckg, x, y
	push y
	push x
	push 0FFFFFFh
	push color
	call make_symbol
	add esp, 16
endm


switch_players macro
	local playerto2, endswtch
	cmp player, 1
	je playerto2
	mov player, 1
	jmp endswtch
playerto2:
	mov player, 2
endswtch:
endm



free_green macro position
	local absolut_free, not_absolut_free, endfree_green, endallgreen, greenplayer2
	mov eax, 0
	cmp position, 23;daca pozitia ezte mai mare decat 23
	jg endfree_green
	cmp position, 0
	jl endfree_green
	
	mov ecx, [t+4*position]
	cmp ecx, 0
	je absolut_free
	mov ecx, [col+4*position]
	cmp ecx, player
	je absolut_free
	mov ecx, [t+4*position]
	cmp ecx, 2
	jl not_absolut_free
	jmp endallgreen
	
absolut_free:
	mov eax, 1
	jmp endallgreen
not_absolut_free:
	mov eax, 2
	jmp endallgreen
	
	
	
endfree_green:	


	cmp player, 2
	je greenplayer2
	cmp scoatere_din_casa_player_1, 0
	je endallgreen
	mov housegreen1, 1
	jmp endallgreen
	
greenplayer2:
	cmp scoatere_din_casa_player_2, 0
	je endallgreen
	mov housegreen2, 1
	jmp endallgreen

endallgreen:	
endm

make_green_if_free macro
local etzar1, etzarzar1, endall,etzar2, etzarzar2, player2
	cmp player, 2
	je player2
	
	mov ebx, pos
	add ebx, zar1
	free_green ebx; ebx= pos+zar
	cmp eax, 0
	je etzar1
	mov [green+4*ebx], 1
etzar1:
	mov ebx, pos
	add ebx, zar2
	free_green ebx
	cmp eax, 0
	je etzarzar1
	mov [green+4*ebx], 1
etzarzar1:
	mov ebx, pos
	add ebx, zar2
	add ebx, zar1
	free_green ebx
	cmp eax, 0
	je endall
	mov [green+4*ebx], 1
	jmp endall
player2:
	mov ebx, pos
	sub ebx, zar1
	free_green ebx
	cmp eax, 0
	je etzar2
	mov [green+4*ebx], 1
etzar2:
	mov ebx, pos
	sub ebx, zar2
	free_green ebx
	cmp eax, 0
	je etzarzar2
	mov [green+4*ebx], 1
etzarzar2:
	mov ebx, pos
	sub ebx, zar2
	sub ebx, zar1
	free_green ebx
	cmp eax, 0
	je endall
	mov [green+4*ebx], 1	

endall:	
endm

valid_roll macro
	local sfarsit
	mov eax, 0;
	mov ebx, [ebp+arg2];x
	mov ecx, [ebp+arg3];y
	cmp ebx, 6*15
	jl sfarsit
	cmp ebx, 22*15
	jg sfarsit
	cmp ecx, 22*15
	jl sfarsit
	cmp ecx, 26*15
	jg sfarsit
	mov eax, 1
sfarsit:
endm

valid_pos_to_click macro
	local jmpto2,jmpto3,jmpto4,jmptoend
	mov eax, 0;
	mov ebx, [ebp+arg2];x
	mov ecx, [ebp+arg3];y
	cmp ebx, 30*15
	jl jmpto2
	cmp ebx, 54*15
	jg jmpto2
	cmp ecx, 12*15
	jl jmpto2
	cmp ecx, 22*15
	jg jmpto2
	mov eax, 1
	jmp jmptoend
jmpto2:
	cmp ebx, 2*15
	jl jmpto3
	cmp ebx, 26*15
	jg jmpto3
	cmp ecx, 12*15
	jl jmpto3
	cmp ecx, 22*15
	jg jmpto3
	mov eax, 2
	jmp jmptoend
jmpto3:
	cmp ebx, 2*15
	jl jmpto4
	cmp ebx, 26*15
	jg jmpto4
	cmp ecx, 26*15
	jl jmpto4
	cmp ecx, 36*15
	jg jmpto4
	mov eax, 3
	jmp jmptoend
jmpto4:
	cmp ebx, 30*15
	jl jmptoend
	cmp ebx, 54*15
	jg jmptoend
	cmp ecx, 26*15
	jl jmptoend
	cmp ecx, 36*15
	jg jmptoend
	mov eax, 4
jmptoend:
endm



zar_get_value macro 
local aici, endd
	rdtsc
	xor edx, edx
	div cinci
	inc edx
	mov zar1, edx
	
	rdtsc
	xor edx, edx
	div cinci
	inc edx
	mov zar2, edx
endd:
endm

init_values macro
	mov [t] , 2
	mov [col], 1
	mov [t+4*5] , 5
	mov [col+4*5] , 2
	mov [t+4*7] , 3
	mov [col+4*7] , 2
	mov [t+4*11] , 5
	mov [col+4*11] , 1
	mov [t+4*12] , 5
	mov [col+4*12] , 2
	mov [t+4*16] , 3
	mov [col+4*16] , 1
	mov [t+4*18] , 5
	mov [col+4*18] , 1
	mov [t+4*23] , 2
	mov [col+4*23] , 2
endm

show_values macro

	mov edx, t+4*11
	add edx, '0'
	make_text_macro edx, area, 4*15-5 , 13*15
	mov edx, t+4*10
	add edx, '0'
	make_text_macro edx, area, 4*15-5+1*60 , 13*15
	mov edx, t+4*9
	add edx, '0'
	make_text_macro edx, area, 4*15-5+2*60 , 13*15
	mov edx, t+4*8
	add edx, '0'
	make_text_macro edx, area, 4*15-5+3*60 , 13*15
	mov edx, t+4*7
	add edx, '0'
	make_text_macro edx, area, 4*15-5+4*60 , 13*15
	mov edx, t+4*6
	add edx, '0'
	make_text_macro edx, area, 4*15-5+5*60 , 13*15
	
	mov edx, t+4*5
	add edx, '0'
	make_text_macro edx, area, 4*15-5+7*60 , 13*15
	mov edx, t+4*4
	add edx, '0'
	make_text_macro edx, area, 4*15-5+8*60 , 13*15
	mov edx, t+4*3
	add edx, '0'
	make_text_macro edx, area, 4*15-5+9*60 , 13*15
	mov edx, t+4*2
	add edx, '0'
	make_text_macro edx, area, 4*15-5+10*60 , 13*15
	mov edx, t+4*1
	add edx, '0'
	make_text_macro edx, area, 4*15-5+11*60 , 13*15
	mov edx, t+4*0
	add edx, '0'
	make_text_macro edx, area, 4*15-5+12*60 , 13*15
	
	
	mov edx, t+4*12
	add edx, '0'
	make_text_macro edx, area, 4*15-5 , 35*15-25
	mov edx, t+4*13
	add edx, '0'
	make_text_macro edx, area, 4*15-5+1*60 , 35*15-25
	mov edx, t+4*14
	add edx, '0'
	make_text_macro edx, area, 4*15-5+2*60 , 35*15-25
	mov edx, t+4*15
	add edx, '0'
	make_text_macro edx, area, 4*15-5+3*60 , 35*15-25
	mov edx, t+4*16
	add edx, '0'
	make_text_macro edx, area, 4*15-5+4*60 , 35*15-25
	mov edx, t+4*17
	add edx, '0'
	make_text_macro edx, area, 4*15-5+5*60 , 35*15-25
	
	mov edx, t+4*18
	add edx, '0'
	make_text_macro edx, area, 4*15-5+7*60 , 35*15-25
	mov edx, t+4*19
	add edx, '0'
	make_text_macro edx, area, 4*15-5+8*60 , 35*15-25
	mov edx, t+4*20
	add edx, '0'
	make_text_macro edx, area, 4*15-5+9*60 , 35*15-25
	mov edx, t+4*21
	add edx, '0'
	make_text_macro edx, area, 4*15-5+10*60 , 35*15-25
	mov edx, t+4*22
	add edx, '0'
	make_text_macro edx, area, 4*15-5+11*60 , 35*15-25
	mov edx, t+4*23
	add edx, '0'
	make_text_macro edx, area, 4*15-5+12*60 , 35*15-25
	
	
endm

show_roll macro
	mov edx, 'R'
	make_text_macro edx, area, 8*15-5 , 23*15
	mov edx, 'O'
	make_text_macro edx, area, 8*15+60-5 , 23*15
	mov edx, 'L'
	make_text_macro edx, area, 8*15+2*60-5 , 23*15
	mov edx, 'L'
	make_text_macro edx, area, 8*15+3*60-5 , 23*15
endm

decide_color macro
local yellow, enddd, whitte
	cmp edx, 1
	je yellow
	cmp edx, 0
	je whitte
	mov edx, 0313022h
	jmp enddd
yellow:
	mov edx, 0F7EF79h
	jmp enddd
whitte:
	mov edx, 0FFFFFFh
enddd:
endm

show_color macro
	mov edx, col+4*11
	decide_color
	make_symbol_macro edx, 0, 4*15-10 , 13*15
	mov edx, col+4*10
	decide_color
	make_symbol_macro edx, 0, 4*15-10+1*60 , 13*15
	mov edx, col+4*9
	decide_color
	make_symbol_macro edx, 0, 4*15-10+2*60 , 13*15
	mov edx, col+4*8
	decide_color
	make_symbol_macro edx, 0, 4*15-10+3*60 , 13*15
	mov edx, col+4*7
	decide_color
	make_symbol_macro edx, 0, 4*15-10+4*60 , 13*15
	mov edx, col+4*6
	decide_color
	make_symbol_macro edx, 0, 4*15-10+5*60 , 13*15
	
	mov edx, col+4*5
	decide_color
	make_symbol_macro edx, 0, 4*15-10+7*60 , 13*15
	mov edx, col+4*4
	decide_color
	make_symbol_macro edx, 0, 4*15-10+8*60 , 13*15
	mov edx, col+4*3
	decide_color
	make_symbol_macro edx, 0, 4*15-10+9*60 , 13*15
	mov edx, col+4*2
	decide_color
	make_symbol_macro edx, 0, 4*15-10+10*60 ,13*15
	mov edx, col+4*1
	decide_color
	make_symbol_macro edx, 0, 4*15-10+11*60 , 13*15
	mov edx, col+4*0
	decide_color
	make_symbol_macro edx, 0, 4*15-10+12*60 , 13*15
	
	
	mov edx, col+4*12
	decide_color
	make_symbol_macro edx, 0, 4*15-10 , 32*15+20
	mov edx, col+4*13
	decide_color
	make_symbol_macro edx, 0, 4*15-10+1*60 , 32*15+20
	mov edx, col+4*14
	decide_color
	make_symbol_macro edx, 0, 4*15-10+2*60 , 32*15+20
	mov edx, col+4*15
	decide_color
	make_symbol_macro edx, 0, 4*15-10+3*60 , 32*15+20
	mov edx, col+4*16
	decide_color
	make_symbol_macro edx, 0, 4*15-10+4*60 , 32*15+20
	mov edx, col+4*17
	decide_color
	make_symbol_macro edx, 0, 4*15-10+5*60 , 32*15+20
	
	mov edx, col+4*18
	decide_color
	make_symbol_macro edx, 0, 4*15-10+7*60 , 32*15+20
	mov edx, col+4*19
	decide_color
	make_symbol_macro edx, 0, 4*15-10+8*60 , 32*15+20
	mov edx, col+4*20
	decide_color
	make_symbol_macro edx, 0, 4*15-10+9*60 , 32*15+20
	mov edx, col+4*21
	decide_color
	make_symbol_macro edx, 0, 4*15-10+10*60 , 32*15+20
	mov edx, col+4*22
	decide_color
	make_symbol_macro edx, 0, 4*15-10+11*60 , 32*15+20
	mov edx, col+4*23
	decide_color
	make_symbol_macro edx, 0, 4*15-10+12*60 , 32*15+20
endm

green_or_not macro
local endgreen, notgreen
	cmp edx, 1
	jne notgreen
	mov edx, 000ff00h
	jmp endgreen
notgreen:
	mov edx, 0FFFFFFh
endgreen:
endm

show_reput macro
	make_symbol_macro 0F7EF79h, 0FFFFFFh, 27*15+5 , 19*15
	mov edx, reput1
	add edx, '0'
	make_text_macro edx, area, 27*15+10 , 19*15
	make_symbol_macro 0313022h, 0FFFFFFh, 27*15+5 , 27*15+10
	mov edx, reput2
	add edx, '0'
	make_text_macro edx, area, 27*15+10 , 27*15+10
endm


show_green macro

	mov edx, green+4*11
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10 , 16*15
	mov edx, green+4*10
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+1*60 , 16*15
	mov edx, green+4*9
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+2*60 , 16*15
	mov edx, green+4*8
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+3*60 , 16*15
	mov edx, green+4*7
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+4*60 , 16*15
	mov edx, green+4*6
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+5*60 , 16*15
	
	mov edx, green+4*5
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+7*60 , 16*15
	mov edx, green+4*4
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+8*60 , 16*15
	mov edx, green+4*3
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+9*60 , 16*15
	mov edx, green+4*2
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+10*60 , 16*15
	mov edx, green+4*1
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+11*60 , 16*15
	mov edx, green+4*0
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+12*60 , 16*15
	
	
	mov edx, green+4*12
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10 , 32*15-20
	mov edx, green+4*13
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+1*60 , 32*15-20
	mov edx, green+4*14
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+2*60 , 32*15-20
	mov edx, green+4*15
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+3*60 , 32*15-20
	mov edx, green+4*16
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+4*60 , 32*15-20
	mov edx, green+4*17
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+5*60 , 32*15-20
	
	mov edx, green+4*18
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+7*60 , 32*15-20
	mov edx, green+4*18
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+8*60 , 32*15-20
	mov edx, green+4*20
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+9*60 , 32*15-20
	mov edx, green+4*21
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+10*60 ,32*15-20
	mov edx, green+4*22
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+11*60 , 32*15-20
	mov edx, green+4*23
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 4*15-10+12*60 , 32*15-20
	
	mov edx, housegreen1
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 27*15 , 36*15
	mov edx, housegreen2
	green_or_not
	make_symbol_macro edx, 0FFFFFFh, 27*15 , 9*15
endm

show_dice macro
	mov edx, zar1
	add edx, '0'
	make_dice_macro edx, area, 39*15-4 , 22*15+10
	mov edx, zar2
	add edx, '0'
	make_dice_macro edx, area, 43*15-4 , 22*15+10
endm

calcpos macro x, y

	mov eax, x
	mov ebx, area_width
	mul ebx
	add eax, y
	shl eax, 2
	add eax, area
	endm
	
linie_horizontal macro x, ystart, ystop
	local buclalinie1
	mov ecx, ystart
buclalinie1:
	
	calcpos x, ecx
	mov dword ptr [eax], 0FF0000h
	dec ecx;
	cmp ecx, ystop
	jnz buclalinie1
endm

linie_vertical macro y, xstart, xstop
	local buclalinie2
	mov ecx, xstart
	
buclalinie2:
	calcpos ecx , y
	mov dword ptr [eax], 0FF0000h
	dec ecx;
	cmp ecx, xstop
	jnz buclalinie2
endm





; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '1'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0ff0000h
	jmp simbol_pixel_next
simbol_pixel_alb:
	;mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click)
; arg2 - x
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 1
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	linie_horizontal 120, 840, 0
	linie_horizontal 12*15, 26*15, 2*15
	linie_horizontal 12*15, 54*15, 30*15
	linie_horizontal 36*15, 26*15, 2*15
	linie_horizontal 36*15, 54*15, 30*15
	linie_horizontal 599, 840, 0
	
	linie_vertical 56*15, 599, 120
	linie_vertical 2*15, 36*15, 12*15
	linie_vertical 26*15, 36*15, 12*15
	linie_vertical 30*15, 36*15, 12*15
	linie_vertical 54*15, 36*15, 12*15
	linie_vertical 0 , 599, 120
	linie_vertical 6*15, 36*15, 12*15
	linie_vertical 10*15, 36*15, 12*15
	linie_vertical 14*15, 36*15, 12*15
	linie_vertical 18*15, 36*15, 12*15
	linie_vertical 22*15, 36*15, 12*15
	linie_vertical 34*15, 36*15, 12*15
	linie_vertical 38*15, 36*15, 12*15
	linie_vertical 42*15, 36*15, 12*15
	linie_vertical 46*15, 36*15, 12*15
	linie_vertical 50*15, 36*15, 12*15
	linie_horizontal 22*15, 54*15, 2*15
	linie_horizontal 26*15, 54*15, 2*15
	
	show_roll
	
	jmp final_draw
	
evt_click:
	
	check_if_all_in_house_player2
	cmp ebx, 1
	je player2_house
	check_if_all_in_house_player1
	cmp ebx, 1
	je player1_house
	jmp house
	
	
	player2_house:
	mov scoatere_din_casa_player_2, 1
	jmp house
	
	player1_house:
	mov scoatere_din_casa_player_1, 1
	jmp house
	
	house:
	
	cmp flux, 0
	je flux0
	cmp flux, 1
	je flux1

flux2:
	
	cmp player, 1
	jne player2checkgreenhouse
	cmp housegreen1, 1
	jne notgreenhouse
	mov edx, [ebp+arg2] ; edx=x
	cmp edx, 32*15
	jg notgreenhouse
	cmp edx, 24*15
	jl notgreenhouse
	mov edx, [ebp+arg3] ; edx=y
	cmp edx, 36*15
	jl notgreenhouse
	cmp edx, 40*15
	jg notgreenhouse
	mov eax, selected
	dec[t+4*eax]
	mov eax, 24
	sub eax, selected
	cmp zar1, eax
	jl etzar2house
	jmp etzar1house
	
	player2checkgreenhouse:
	cmp housegreen2, 1
	jne notgreenhouse
	mov edx, [ebp+arg2] ; edx=x
	cmp edx, 32*15
	jg notgreenhouse
	cmp edx, 24*15
	jl notgreenhouse
	mov edx, [ebp+arg3] ; edx=y
	cmp edx, 8*15
	jl notgreenhouse
	cmp edx, 12*15
	jg notgreenhouse
	mov eax, selected
	dec[t+4*eax]
	cmp zar1, eax
	jl etzar2house
	jmp etzar1house
	
	etzar1house:
			mov zar1, 0
			jmp endzarurihouse
	etzar2house:
			mov zar2, 0
			jmp endzarurihouse
	endzarurihouse:
		
		cmp zar1, 0
		jne fluxto1house
		cmp zar2, 0
		jne fluxto1house
		mov flux, 0
		jmp endmovingfluxhouse
		fluxto1house:
			mov flux, 1
	endmovingfluxhouse:
	
	mov eax, selected
		cmp [t+4*eax], 0
		jne etlasthouse
		mov [col+eax*4], 0
		
	etlasthouse:
		mov ecx, 23
		make_not_green2house:
			mov [green+4*ecx],0
			loop make_not_green2house
		mov [green],0
		mov housegreen1, 0
		mov housegreen2, 0
		
	cmp flux, 0
	jne endflux
	switch_players
	jmp endflux
	
	
	
	notgreenhouse:
	valid_pos_to_click
	cmp eax, 1
	je valid1flux2
	cmp eax, 2
	je valid2flux2
	cmp eax, 3
	je valid3flux2
	cmp eax, 4 
	je valid4flux2
	jmp endflux
	valid1flux2:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 54*15
		sub ecx, edx
		mov eax, ecx; eax=54*15-x
		mov edx, 0
		mov ecx, 60
		div ecx
		mov pos, eax
		jmp validposflux2
	valid2flux2:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 26*15
		sub ecx, edx
		mov eax, ecx; eax=26*15-x
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 6
		mov pos, eax
		jmp validposflux2
	valid3flux2:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 2*15
		sub edx, ecx
		mov eax, edx; eax=x-2*15
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 12
		mov pos, eax
		jmp validposflux2
	valid4flux2:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 30*15
		sub edx, ecx
		mov eax, edx; eax=x-30*15
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 18
		mov pos, eax
		jmp validposflux2
	validposflux2:
		
		cmp reput1, 0
		jne player_reput1_flux2
		cmp reput2, 0
		jne player_reput2_flux2
		jmp continue2
		
		player_reput1_flux2:
		cmp player, 1
		je reput_part2
		jmp continue2
		
		player_reput2_flux2:
		cmp player, 2
		je reput_part2
		jmp continue2
		
	continue2:
		mov edx, pos
		cmp edx, selected
		jne notsamepos
			mov flux, 1
			mov selected, -1
			mov ecx, 23
		make_not_green:
			mov [green+4*ecx],0
			loop make_not_green		
		mov [green],0
		mov housegreen1, 0
		mov housegreen2, 0
		jmp endflux
		
		
	notsamepos:
		mov eax, pos
		mov eax, [green+eax*4]
		cmp eax, 1
		jne endflux
		
		
		mov eax, pos
		mov ebx, selected
		cmp eax, ebx
		jl maimic
			sub eax, ebx
			jmp endmaimic
		maimic:
			sub ebx, eax
			mov eax, ebx
		endmaimic:		
		;eax= |pos-selected|
		
		
		cmp eax, zar1
		je etzar1
		cmp eax, zar2
		je etzar2
			mov zar1, 0
			mov zar2, 0
			jmp endzaruri
		etzar1:
			mov zar1, 0
			jmp endzaruri
		etzar2:
			mov zar2, 0
			jmp endzaruri
		endzaruri:
		;zarul care este egal cu |pos-selected| devine 0
		
		cmp zar1, 0
		jne fluxto1
		cmp zar2, 0
		jne fluxto1
		mov flux, 0
		jmp endmovingflux
		fluxto1:
			mov flux, 1
	endmovingflux:
		;daca toate zarurile au valoarea 0 flux devine 0, altfel devine 1
		
		mov eax, pos
		mov eax, [col+eax*4]
		cmp eax, 0
		je etnormala
		
		mov ebx, player
		cmp eax, ebx
		jne scoatere
		
		;daca pe pozitie nu sunt piese sau piesa care urmeaza sa fie pus pe pozitie are acelasi culoare ca piesele aflate deja acolo:
	etnormala:
		mov eax, selected
		mov ebx, pos
		dec [t+eax*4]
		inc [t+ebx*4]
		mov eax, pos
		cmp [col+4*eax], 0
		jne check_color
		mov ebx, player
		mov [col+4*eax], ebx
		jmp check_color
		
		;daca nu, deci urmeaza sa fie scoasa o piese
	scoatere:
		mov ebx, player
		mov eax, pos
		mov [col+eax*4], ebx
		mov eax, selected
		dec [t+4*eax]
		cmp player, 1
		je firstplayer
		add reput1, 1
		jmp check_color
		
		firstplayer:
		add reput2,1
		
		
	check_color:;ne uitam daca la pozitia selected mai raman piese, sau nu, si daca nu, culoarea devine 0
		mov eax, selected
		cmp [t+4*eax], 0
		jne etlast
		mov [col+eax*4], 0
		
	etlast:
		mov ecx, 23
		make_not_green2:
			mov [green+4*ecx],0
			loop make_not_green2
		mov [green],0
		mov housegreen1, 0
		mov housegreen2, 0
		
	cmp flux, 0
	jne endflux
	switch_players
	jmp endflux
		
	
	
flux1:
	
	cmp reput1, 0
	jne player_reput1
	cmp reput2, 0
	jne player_reput2
	jmp continue
	
	player_reput1:
	cmp player, 1
	je reput
	jmp continue
	
	player_reput2:
	cmp player, 2
	je reput
	jmp continue
	
	continue:
	valid_pos_to_click
	cmp eax, 1
	je valid1
	cmp eax, 2
	je valid2
	cmp eax, 3
	je valid3
	cmp eax, 4 
	je valid4
	jmp endflux
	valid1:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 54*15
		sub ecx, edx
		mov eax, ecx; eax=54*15-x
		mov edx, 0
		mov ecx, 60
		div ecx
		mov pos, eax
			mov ebx, 10
			mov eax, pos
			;cifra unitatilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 30, 10
			;cifra zecilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 20, 10
			;cifra sutelor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 10, 10
		jmp validpos
	valid2:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 26*15
		sub ecx, edx
		mov eax, ecx; eax=26*15-x
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 6
		mov pos, eax
			mov ebx, 10
			mov eax, pos
			;cifra unitatilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 30, 10
			;cifra zecilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 20, 10
			;cifra sutelor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 10, 10
		jmp validpos
	valid3:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 2*15
		sub edx, ecx
		mov eax, edx; eax=x-2*15
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 12
		mov pos, eax
			mov ebx, 10
			mov eax, pos
			;cifra unitatilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 30, 10
			;cifra zecilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 20, 10
			;cifra sutelor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 10, 10
		jmp validpos
	valid4:
		mov edx, [ebp+arg2]; edx=x
		mov ecx, 30*15
		sub edx, ecx
		mov eax, edx; eax=x-30*15
		mov edx, 0
		mov ecx, 60
		div ecx
		add eax, 18
		mov pos, eax
			mov ebx, 10
			mov eax, pos
			;cifra unitatilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 30, 10
			;cifra zecilor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 20, 10
			;cifra sutelor
			mov edx, 0
			div ebx
			add edx, '0'
			make_text_macro edx, area, 10, 10
		jmp validpos
	validpos:
	
		mov edx, player
		mov ecx, pos
		mov ecx, [col+4*ecx]
		cmp edx, ecx
		jne endflux
		make_green_if_free
		mov flux, 2
		mov eax, pos
		mov selected, eax
		mov eax, pos
		mov pos, eax
		
	jmp endflux
flux0:
	valid_roll
	cmp eax, 1
	jne endflux
	zar_get_value
	mov flux, 1
	jmp endflux
	
 reput:
	cmp reput1, 0
	je jucator2
	mov ebx, [ebp+arg2];x
	mov ecx, [ebp+arg3];y
	cmp ebx, 30*15
	jg endflux
	cmp ebx, 26*15
	jl endflux
	cmp ecx, 12*15
	jl endflux
	cmp ecx, 22*15
	jg endflux
	
	mov eax, zar1
	dec eax
	mov [green+4*eax], 1
	mov eax, zar2
	dec eax
	mov [green+4*eax], 1
	mov flux, 2
	jmp endflux
	
	
	jucator2:
	mov ebx, [ebp+arg2];x
	mov ecx, [ebp+arg3];y
	cmp ebx, 30*15
	jg endflux
	cmp ebx, 26*15
	jl endflux
	cmp ecx, 26*15
	jl endflux
	cmp ecx, 36*15
	jg endflux
	
	mov eax, 24
	sub eax, zar1
	mov [green+4*eax], 1
	mov eax, 24
	sub eax, zar2
	mov [green+4*eax], 1
	mov flux, 2
	 jmp endflux
	
reput_part2:

	mov eax, pos
	mov eax, [green+eax*4]
	cmp eax, 1
	jne endflux

	cmp reput1, 0
	je jucator2_part2
	mov eax, pos
	inc [t+4*eax]
	mov ebx, player
	mov [col+4*eax], ebx
	mov eax, pos
	inc eax
	dec reput1
	cmp zar1, eax
	je zarul1
	jmp zarul2
	
	
	
	
	jucator2_part2:
	mov eax, pos
	add [t+4*eax], 1
	mov ebx, player
	mov [col+4*eax], ebx
	mov eax, 24
	sub eax, pos
	dec reput2
	cmp zar1, eax
	je zarul1
	jmp zarul2
	
	zarul1:
	mov zar1, 0
	jmp endzarurireput
	zarul2:
	mov zar2,0
	
	endzarurireput:
	cmp zar1, 0
		jne fluxto1reput
		cmp zar2, 0
		jne fluxto1reput
		mov flux, 0
		jmp endmovingfluxreput
		fluxto1reput:
			mov flux, 1
	endmovingfluxreput:
		;daca toate zarurile au valoarea 0 flux devine 0, altfel devine 1
	
		mov ecx, 23
		make_not_green2reput:
			mov [green+4*ecx],0
			loop make_not_green2reput
		mov [green],0
		mov housegreen1, 0
		mov housegreen2, 0
		
	cmp flux, 0
	jne endflux
	switch_players
	jmp endflux
	
endflux:
	jmp final_draw
	
evt_timer:
	inc counter
	

final_draw:
	
	show_green
	show_color
	show_reput
	show_values
	show_dice
	
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	
	init_values
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
