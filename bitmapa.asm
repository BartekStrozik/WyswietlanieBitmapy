data1 segment
	;czytanie pliku
	nazwa1 db 30 dup(?)
	uchwyt dw ?
	buf db 106 dup(?)
	
	;parametry obrazka
	offset_pixeli	dw ?
	szerokosc dw ?
	
	;pochodne od rozmiarow obrazka
	od_gory dw 200
	od_lewej dw 0
	
	;paleta kolorow
	red   db ?		;;;
    green db ?		;;skladowe RGB
    blue  db ?		;;;
	kol db ? 		;pelny kolor w jednym bajcie [0..255]
	pixel db 3 dup(?)			;1 piksel zczytany z obrazka
	
	;wyswietlanie obrazka
	x dw ?
	y dw ?
	
	x1 dw ?
	y1 dw ?
	
	;fragment obrazka do wyswietlenia
	ramka_x dw 320
	ramka_y dw 200
	
	skala dw 1
	
	;proporcja przesuwania do przyblizenia
	translacja dw 100
data1 ends

code1 segment

start:

;=========================================ETAP-I OTWARCIE PLIKU==========================================

	;zapisanie w odpowiednie miejsce segmentu stosu
	mov ax,seg ws1
	mov ss,ax
	mov sp,offset ws1

	;pobranie argumentu wywolania programu
	mov ax,seg nazwa1				;do tej zmiennej zapiszemy argument
	mov es,ax
	mov dx,offset nazwa1
	
	mov di,dx						;w DI zmienna do przechowania nazwy
	mov si,82h						;SI wskazuje na poczatek argumentu
	xor cx,cx
	mov cl,byte ptr ds:[80h]		;dlugosc wprowadzonego argumentu
	dec cl							;minus jeden znak na spacje
	cld
	rep movsb						;SI -> DI

	;otwarcie pliku, zapisanie uchwytu do pliku
	mov ax,seg nazwa1
	mov ds,ax
	mov dx,offset nazwa1
	mov ax,3d00h					;otwarcie pliku o nazwie w DS:DX
	int 21h
	mov word ptr ds:[uchwyt],ax		;zapamietanie uchwytu do pliku

;=========================================ETAP-II POBRANIE PARAMETROW PLIKU I OBRAZKA==========================================
	
	;przeczytanie 106 bajtow do bufora - naglowek pliku i naglowek DIB
	mov ax,seg buf
	mov ds,ax
	mov dx,offset buf				;w DX bufor do zawartosci pliku
	mov cx,106
	mov bx,word ptr ds:[uchwyt]		;w BX uchwyt - do czytania
	xor al,al
	mov ah,3fh						;czytanie pliku
	int 21h
	
	;zapisanie adresu do tablicy pixeli
	mov ax,word ptr ds:[buf+10]
	mov word ptr ds:[offset_pixeli],ax
	
	;pobranie wymiarow pliku i nastepnie ustawienie odpowiednich wartosci do przeskakiwania w wyswietlaniu pliku
	mov bx,word ptr ds:[buf+18]			;szerokosc obrazu
	xor ax,ax
	mov al,byte ptr ds:[buf+28]			;liczba bitow na piksel
	mul bx								;liczba bitow w calej szerokosci
	
	add ax,31		;+31
	mov bx,32		;/32
	div bx
	mov bx,4		;*4
	mul bx			;w AX znajduje sie teraz wartosc: [ ((bpp*szerokosc)+31)/32 ] * 4
	mov word ptr ds:[szerokosc],ax		;w efekcie do zmiennej szerokosc wedruje liczba BAJTOW na wiersz spelniajaca warunki:
	
	;jeden piksel zapisany jest na 3 bajtach
	;liczba bajtow w jednej linii musi byc podzielna przez 4 (80 px -> 240B, 81 px -> 244B, 82 px -> 248B, 83 px -> 252B, 84 px -> 252B)
	;liczba bajtow musi byc najmniejsza mozliwa

;=========================================ETAP-III TRYB GRAFICZNY, PALETA, USTAWIENIE POZYCJI W PIXEL-TABLE==========================================
	
	mov al,13h			;tryb graficzny 13h
	xor ah,ah			;wejscie w tryb VGA
	int 10h
	
	;wywolanie procedury, ktora przypisuje kolejne liczby [0..255] barwom w RGB
	call konfiguracja_palety
	
tablica_pikseli:
	;przesuniecie pozycji w pliku do tablicy pikseli
	mov bx,word ptr ds:[uchwyt]
	mov ax,word ptr ds:[offset_pixeli]
	xor cx,cx
	mov dx,ax				;w CX:DX offset: dokad przesunac pozycje
	mov ax,4200h			;w AH przesuwanie, w AL - 0, czyli wzgledem poczatku pliku
	int 21h
	
tnij:
	;ustawienie sie na osi Y, to znaczy na odleglosc 'od_gory' - plik bedzie wczytywany z dolu do gory
	mov ax,word ptr ds:[buf+22]			;wysokosc obrazu
	cmp ax,200
	jl przesun
	sub ax,word ptr ds:[od_gory]		;w AX liczba wierszy, ktora ominiemy od dolu obrazka
	mov bx,word ptr ds:[szerokosc]	
	mul bx								;w AX liczba bajtow, ktora ominiemy
	mov cx,dx
	mov dx,ax
	mov ah,42h							;przesuwamy sie w pliku do odpowiedniego wiersza obrazka
	mov al,1
	mov bx,word ptr ds:[uchwyt]
	int 21h
	
przesun:
	;ustawienie sie na osi X
	mov ax,word ptr ds:[od_lewej]		;domyslnie tutaj 0, zmienia sie na wiecej przy naciskaniu strzalki ->
	xor bx,bx
	mov bl,3
	mul bx								;liczba bajtow do przesuniecia
	xor cx,cx
	mov dx,ax
	mov ah,42h
	mov al,1							;przesuwamy sie w pliku na odpowiednia wspolrzedna x
	mov bx,word ptr ds:[uchwyt]
	int 21h
	
;=========================================ETAP-IV WYSWIETLENIE (opcja: LEWEGO-GORNEGO ROGU) OBRAZKA==========================================	

	mov word ptr ds:[y],199				;w trybie VGA, w segmencie pamieci obrazu przechodzimy zawsze po osi Y: 199 -> 0
	mov cx,word ptr ds:[ramka_y]
	wiersze:
		push cx
		
		mov word ptr ds:[x],0			;po osi X: 0 -> 319
		mov cx,word ptr ds:[ramka_x]
		komorki:
			push cx
			
			call czytaj_pixel			;czytamy kolejne bajty z pliku
			call rozbij_pixel			;z zapisanego bufora rozbijamy piksel na skladowe RGB i scalamy je w jeden bajt - kol
			call zapal_punkt			;segment_pamieci_obrazu : P(x,y) <- kol
			
			mov ax,word ptr ds:[skala]
			add word ptr ds:[x],ax
				
			pop cx
		loop komorki
		call skacz
		
		mov ax,word ptr ds:[skala]
		sub word ptr ds:[y],ax
		
		pop cx
	loop wiersze

;=========================================ETAP-V PRZESUWANIE RAMKI NA OBRAZEK==========================================

przesuwaj_obrazek:
	xor ax,ax
	int 16h			;czekaj na klawisz
	
	in al,60h
	cmp al,1		;ESC
	je zakoncz
	
	;strzalki
	cmp al,72		
	je w_gore
	cmp al,75
	je w_lewo
	cmp al,77
	je w_prawo
	cmp al,80
	je w_dol
	
	cmp al,13
	je przybliz
	
	jmp przesuwaj_obrazek

;=========================================ETAP-VI ZAKONCZENIE PROGRAMU==========================================
	
zakoncz:
	;powrot do trybu tekstowego
	mov al,3h
	mov ah,0
	int 21h
	
	;zamknij plik
	mov bx,word ptr ds:[uchwyt]
	mov ah,3eh
	int 21h
	
	;zakoncz
	mov ax,04c00h
	int 21h

;==================PROCEDURY=====================

konfiguracja_palety:
    mov byte ptr ds:[red],0
    mov cl,0
    czerwone:
        mov byte ptr ds:[green],0
        zielone:
            mov byte ptr ds:[blue],0
            niebieskie:
                
                mov dx,3C8h
                mov al,cl
                out dx,al
                mov dx,3C9h
                mov al,byte ptr ds:[red]
                out dx,al
                mov al,byte ptr ds:[green]
                out dx,al
                mov al,byte ptr ds:[blue]
                out dx,al
                
                inc cl
            
            add byte ptr ds:[blue],21
            cmp byte ptr ds:[blue],84    
            jne niebieskie
        
        add byte ptr ds:[green],9    
        cmp byte ptr ds:[green],72
        jne zielone
        
    add byte ptr ds:[red],9
    cmp byte ptr ds:[red],72
    jne czerwone
    ret

czytaj_pixel:
	;ustawienie zapisywania do pixela
	mov ax,seg pixel
	mov ds,ax
	mov dx,offset pixel
	;wskaznik miejsca w pliku
	mov bx,word ptr ds:[uchwyt]
	;zczytanie 3 bajtow
	push cx
	
	xor cx,cx
	mov cx,3
	mov ah,3fh
	int 21h
	
	pop cx
	ret

rozbij_pixel:
	;kolor niebieski
	mov al,byte ptr ds:[pixel]
	xor ah,ah
	mov bl,64		;64 = 2^ 6
	div bl			;przesuwamy o 6 bitow w prawo, czyli: xxxx|xxBB
	mov byte ptr ds:[blue],al
	
	;kolor zielony
	mov al,byte ptr ds:[pixel+1]
	xor ah,ah
	mov bl,32		;32 = 2^ 5
	div bl			;przesuwamy o 5 w prawo: xxxx|xGGG
	mov bl,4		;4 = 2^ 2
	mul bl			;nastepnie o dwa w lewo: xxxG|GG00
	mov byte ptr ds:[green],al
	
	;kolor czerwony 
	mov al,byte ptr ds:[pixel+2]
	xor ah,ah
	mov bl,32		;32 = 2^ 5
	div bl			;o 5 w prawo: xxxx|xRRR
	mov bl,32		;32 = 2^ 5
	mul bl			;i o 5 w lewo: RRR0|0000
	mov byte ptr ds:[red],al
	
	;tak przygotowane skladowe RGB zapisujemy w jednym bajcie
	;(beda od teraz reprezentowane jako liczba 0..255)
	mov bl,byte ptr ds:[blue]
	mov bh,byte ptr ds:[green]			;sumujemy kolejno kolory
	add bl,bh
	mov bh,byte ptr ds:[red]			;sumujemy dalej, wynik w BL
	add bl,bh							;nie dojdzie do przepelnienia, bo niebieski <= 3, zielony <= 28, czerwony <= 224	czyli suma <=255
	
	mov byte ptr ds:[kol],bl		;wynik w kol
	ret

zapal_punkt:
	;w ES zapisujemy adres segmentu pamieci obrazu
	mov ax,0a000h			;segment pamieci obrazu
	mov es,ax
	
	mov ax,word ptr ds:[y]
	mov word ptr ds:[y1],ax
	
	mov cx,word ptr ds:[skala]
	szer_kwadratu:
		push cx
		
		mov ax,word ptr ds:[x]
		mov word ptr ds:[x1],ax

		mov cx,word ptr ds:[skala]
		wys_kwadratu:
			push cx
		
			mov bx,320
			mov ax,word ptr ds:[y1]
			mul bx
			mov bx,word ptr ds:[x1]
			add bx,ax
	
			mov al,byte ptr ds:[kol]					
			mov byte ptr es:[bx],al
			
			inc word ptr ds:[x1]
			
			pop cx
			
			;sprawdzenie wyjscia poza zakres
			mov ax,word ptr ds:[x1]
			mov bx,320d
			;gdy x osiagnie 320 to znaczy, ze czas wyjsc z petli - nie chcemy, zeby jakis kolor zawinal sie do wiersza wyzej!
			cmp ax,bx
			je x_poza_zakresem
			
		loop wys_kwadratu
		x_poza_zakresem:
		dec word ptr ds:[y1]
		
		;sprawdzenie wyjscia poza zakres
		mov ax,word ptr ds:[y1]
		mov bx,210
		;gdy y osiagnie 0 to w porzadku, ale pozniej nie osiagnie wartosci ujemnych tylko nastapi przepelnienie!
		;y bedzie wiec znacznie wieksze od 200, wystarczy wiec sprawdzic, ze jest wieksze od 210 - wtedy na pewno nastapil niedomiar
		cmp ax,bx
		jge y_poza_zakresem
		
		pop cx
	loop szer_kwadratu
	
	y_poza_zakresem:
	ret

skacz:
	;znowu przesuwamy sie w pliku, tym razem do nowej linii
	mov ax,word ptr ds:[ramka_x]			;w skoku liczba pixeli do przeskoczenia
	mov dx,3
	mul dx
	mov bx,ax			;tutaj liczba bajtow przypadajaca na jeden wiersz do wyswietlenia w ramce
	mov ax,word ptr ds:[szerokosc]	;liczba bajtow w pelnym wierszu obrazka
	sub ax,bx			;w ten sposob przeskoczymy do nowego wiersza do wyswietlenia w ramce
	mov dx,ax
	xor cx,cx
	mov ax,4201h
	mov bx,word ptr ds:[uchwyt]
	int 21h
	ret

w_dol:
	mov cx,word ptr ds:[translacja]
	add word ptr ds:[od_gory],cx
	
	mov ax,word ptr ds:[od_gory]
	mov bx,word ptr ds:[buf+22]
	cmp ax,bx
	jbe tablica_pikseli
	
	mov word ptr ds:[od_gory],bx
	jmp tablica_pikseli
	
w_gore:
	mov cx,word ptr ds:[translacja]
	sub word ptr ds:[od_gory],cx
	
	mov ax,word ptr ds:[od_gory]
	mov bx,word ptr ds:[ramka_y]
	cmp ax,bx
	ja tablica_pikseli
	
	mov ax,word ptr ds:[ramka_y]
	mov word ptr ds:[od_gory],ax
	jmp tablica_pikseli

w_lewo:
	mov cx,word ptr ds:[translacja]
	
	mov ax,word ptr ds:[od_lewej]
	mov bx,cx
	cmp ax,bx
	mov word ptr ds:[od_lewej],0
	jb tablica_pikseli
	
	mov word ptr ds:[od_lewej],ax
	sub word ptr ds:[od_lewej],cx
	jmp tablica_pikseli

w_prawo:
	mov cx,word ptr ds:[translacja]
	
	add word ptr ds:[od_lewej],cx
	
	mov ax,word ptr ds:[od_lewej]
	mov bx,word ptr ds:[buf+18]
	sub bx,word ptr ds:[ramka_x]
	cmp ax,bx
	jbe tablica_pikseli
	
	mov word ptr ds:[od_lewej],bx
	jmp tablica_pikseli

przybliz:
	inc word ptr ds:[skala]			;zwiekszamy o jeden skale: pojedyncze piksele -> kwadraty 2x2 -> 3x3 -> 4x4 ...
	
	mov ax,320						;
	mov bx,word ptr ds:[skala]		;;dzielenie szerokosci ramki przez wartosc skali
	div bl							;
	
	cmp ah,0
	je bez_reszty1
	xor ah,ah
	inc al
	bez_reszty1:
	mov word ptr ds:[ramka_x],ax	;
	
	mov bx,320
	sub bx,ax
	mov ax,bx				;w AX jest roznica miedzy 320, a szerokoscia ramki
	mov bl,2
	div bl					;co dzielimy na dwa
	xor ah,ah
	add word ptr ds:[od_lewej],ax	;tak wnikniemy do srodka obrazka, ktory chcemy ukazac po przyblizeniu
	
	mov ax,200						;
	mov bx,word ptr ds:[skala]		;;analogicznie jej wysokosc
	div bl							;
	
	cmp ah,0
	je bez_reszty2
	xor ah,ah
	inc al
	bez_reszty2:
	mov word ptr ds:[ramka_y],ax	;
	
	mov bx,200
	sub bx,ax
	mov ax,bx
	mov bl,2
	div bl
	xor ah,ah
	sub word ptr ds:[od_gory],ax	;analogicznie jak poprzednio

	;jeszcze zmniejszenie translacji
	mov bx,word ptr ds:[skala]
	mov ax,word ptr ds:[translacja]
	div bl
	xor ah,ah
	mov word ptr ds:[translacja],ax
	
	mov ax,10
	add word ptr ds:[translacja],ax

	jmp tablica_pikseli

code1 ends

stack1 segment STACK
		dw 240 dup(?)
	ws1 dw ?
stack1 ends

end start