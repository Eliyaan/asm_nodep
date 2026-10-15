; Pong in ASM
; written in fasm: https://flatassembler.net/
;
; useful docs :
; https://flatassembler.net/docs.php?article=manual for the general fasm syntax (for using the default macros of fasm)
; https://flatassembler.net/docs.php?article=fasmg_manual for the macro syntax (the programming langage on which
;	the macros are defined)
; https://refspecs.linuxfoundation.org/elf/x86_64-abi-0.99.pdf (chapter A.2 AMD64 Linux Kernel Conventions for
; 	for syscalls and user-level applications and chapter 3.2)
;	/!\ align your stack to 16 bytes when calling a C function on linux
;	https://tronche.com/gui/x/xlib/window/ for X11 documentation https://tronche.com/gui/x/xlib-tutorial/
;	https://www.x.org/ProgrammingDocumentation/
;
; fasm2 pong.asm
; mold -o pong pong.o --dynamic-linker=/lib64/ld-linux-x86-64.so.2 --library-path=/usr/lib64 -lX11
;


format ELF64

iterate extern_name,\
	XOpenDisplay, XCreateSimpleWindow, XMapWindow, XCreateImage, XDestroyWindow, XDefaultRootWindow,\
	XCreateGC, XFlush, XPutImage, XDefaultVisual, XSelectInput
	extrn extern_name 
end iterate

StructureNotifyMask 	:= 1 shl 17 	; taken in /usr/include/X11/X.h
ZPixmap			:= 2		; taken in /usr/include/X11/X.h
 

bits_per_pixel		:= 32
bytes_per_pixel		:= bits_per_pixel/8

macro linux_syscall number* , args&
	mov rax , number
	iterate arg , args
		if      1 = %
			mov rdi , arg
		else if 2 = %
			mov rsi , arg
		else if 3 = %
			mov rdx , arg
		else if 4 = %
			mov r10 , arg
		else if 5 = %
			mov r8  , arg
		else if 6 = %
			mov r9  , arg
		else
			err 'too many arguments' , %
		end if
	end iterate 
	syscall
end macro

macro linux_syscall_exit exit_code
	linux_syscall 60, exit_code
end macro

macro dont_use_linux_fn_call name*, args& 
	iterate arg, args
		if 1=%
			mov rdi,arg
		else if 2=%
			mov rsi,arg
		else if 3=%
			mov rdx,arg
		else if 4=%
			mov rcx,arg
		else if 5=%
			mov r8,arg
		else if 6=%
			mov r9,arg
		else
			err 'too many arguments',%
		end if
	end iterate 
	call name
end macro

section '.rodata' 
title:	db "Pong in ASM", 0
label screen_buf_h 		: dword ; screen height
	dd 700
label screen_buf_w 		: dword ; screen width
	dd 1300
label bytes_per_line		: dword ; How many bytes a line takes in the buffer for the screen (screen_buf)
	dd 1300 * bytes_per_pixel	; w * byte_depth

section '.data' writeable 
thingy:	db "Pong in ASM", 0
label sleepframe		: qword ; struct timespec (meant to be passed as a pointer) for nanosleep syscall
	dq 0				; 0s
	dq 16_000_000			; 16ms
label cpu_basefreq		: qword ; base frequency of the CPU in Hz ; TODO get that with CPUID
	dq 2_000_000_000		;(for RDTSC calculations)
label ns_frame_target		: dword ; how many ns is the target of a frame
	dd 16_000_000
label rising			: byte
	db 0
label timing_text		: byte
	db 'A','B','C','.','A','B','C','m','s'
;label font			: byte
;	file 'monogram'


section '.bss' writeable
label X11_display		: qword ; Identifier for the app to talk with the X Server
	rq 1
label X11_default_visual	: qword ; Pointer to default visual
	rq 1
label X11_screen_image 		: qword ; Pointer to image used for the screen
	rq 1
label startframe_tsc		: qword ; value read of RDTSC
	rq 1
label old_startframe_tsc	: qword ; previous frame value read of RDTSC
	rq 1
label old_frame_time		: qword ; previous RDTSC clock time elasped to process the frame
	rq 1
label debug 			: qword ;
	rq 1
label X11_window		: dword ; Window ID 
	rd 1
label X11_root_window		: dword ; Root window ID 
	rd 1
label X11_graphics_context	: dword ; Graphics context ID 
	rd 1
label screen_buf		: qword ; the software rendering screen ; TODO allocate this on app startup
	rd 1300*700			; w * h

section '.text' executable
public _start ; make _start available to the linker (if it is not public the name is not kept)
_start:

	rdtsc
	shl rdx , 32
	or rax , rdx
	mov [startframe_tsc] , rax

	mov eax , [screen_buf_h]
	mov ecx , [screen_buf_w]
	mul ecx
	loop_init_screen:
	mov dword [screen_buf + eax * 4] , 0x000000FF
	dec eax
	cmp eax , 0
	jge loop_init_screen	

	mov rdi , 0
	call XOpenDisplay
	mov [X11_display] , rax

	mov rdi , [X11_display]
	call XDefaultRootWindow
	mov [X11_root_window] , eax

	mov esi , 0
	mov rdi , [X11_display]
	call XDefaultVisual
	mov [X11_default_visual] , rax

	mov eax , 0			
	push rax			; padding to align the stack to 16 bytes
	mov eax , 0x00000000
	push rax			; background
	mov eax , 0
	push rax			; border
	mov eax , 0
	push rax			; border_width
	mov r9d , 700			; height
	mov r8d , 1300			; width
	mov ecx , 0			; y
	mov edx , 0			; x
	mov esi , [X11_root_window]	; parent window 
	mov rdi , [X11_display]
	call XCreateSimpleWindow
	mov [X11_window] , eax

	mov edx , StructureNotifyMask
	mov esi , [X11_window]
	mov rdi , [X11_display]
;	call XSelectInput TODO

	mov rcx , 0
	mov rdx , 0
	mov esi , [X11_window]
	mov rdi , [X11_display]
	call XCreateGC
	mov [X11_graphics_context] , eax

	mov esi , [X11_window]
	mov rdi , [X11_display]
	call XMapWindow

	mov eax , [bytes_per_line]
	push rax
	mov eax , bits_per_pixel		; bitmap_pad
	push rax
	mov eax , [screen_buf_h]
	push rax
	mov eax , [screen_buf_w]
	push rax
	lea r9d , [screen_buf]			; data
	mov r8d , 0				; offset 
	mov ecx , ZPixmap			; format (ZPixmap is the default)
	mov edx , 24				; depth of the screen (not depth of the buffer) (bits per pixel)
	mov rsi , [X11_default_visual]
	mov rdi , [X11_display]
	call XCreateImage
	mov [X11_screen_image] , rax

mainLoop:
	mov rax , [startframe_tsc]
	mov [old_startframe_tsc] , rax
	rdtsc
	shl rdx , 32
	or rax , rdx
	mov [startframe_tsc] , rax

; TODO take focus when mapped

; TODO
;      // Wait for the MapNotify event
;
;      for(;;) {
;	    XEvent e;
;	    XNextEvent(dpy, &e);
;	    if (e.type == MapNotify)
;		  break;
 ;     }




	mov ebx , dword [screen_buf]
	cmp [rising] , 0
	je decrease_lum
	inc ebx
	cmp ebx , 255
	jne end_lum
	mov [rising] , 0
	jmp end_lum
	decrease_lum:
	dec ebx
	jnz end_lum
	mov [rising] , 1
	end_lum:
	mov eax , [screen_buf_h]
	mov ecx , [screen_buf_w]
	mul ecx
	loop_update_screen:
	mov dword [screen_buf + eax * 4] , ebx
	dec eax
	cmp eax , 0
	jge loop_update_screen

	mov rax , [old_frame_time]
	call clocktime_to_ns
	call show_ns_to_screen_in_timing_frame
	
	mov rax , [startframe_tsc]
	sub rax , [old_startframe_tsc]
	call clocktime_to_ns
	call show_ns_to_screen_in_timing_frame
	
	
	


	mov rax , 700
	push rax			; height
	mov rax , 1300
	push rax			; width
	mov rax , 0
	push rax			; dest_y
	push rax			; dest_x
	mov r9d , 0			; src_y
	mov r8d , 0			; src_x
	mov rcx , [X11_screen_image]
	mov edx , [X11_graphics_context]
	mov esi , [X11_window]
	mov rdi , [X11_display]
	call XPutImage

	mov rdi , [X11_display]
	call XFlush

	; 0_016_000_000 - (RDTSC_delta * 1_000_000_000 / cpu_basefreq)
	rdtsc
	shl rdx , 32
	or rax , rdx
	mov rdx , [startframe_tsc]
	sub rax , rdx	 		; delta TSC of the frame
	mov [old_frame_time] , rax
	call clocktime_to_ns		; convert delta TSC to delta nanoseconds	

	mov edx	, [ns_frame_target]
	sub rdx , rax			; rdx : how many ns to sleep for 60fps
	mov [sleepframe+8] , rdx	
	mov rax , 35 			; nanosleep
	lea rdi , [sleepframe]
	mov rsi , 0
	syscall				

	jmp mainLoop

	mov esi , [X11_window]
	mov rdi , [X11_display]
	call XDestroyWindow

	linux_syscall_exit 0 

	
; input rax = clock ticks
; output rax = converted to ns 
; written registers : rdx, rcx
clocktime_to_ns:
	mov rcx , 1_000_000_000
	xor rdx , rdx			; rdx is the upper part of the RDX:RAX first operand
	mul rcx				; rax * rcx 
	mov rcx , [cpu_basefreq]
	xor rdx , rdx			; rdx is the upper part of the dividend
	div rcx
	ret

; input rax = ns ticks
; written registers : rdx, rcx
show_ns_to_screen_in_timing_frame:
	; convert ns to us
	xor rdx , rdx
	mov rcx , 1000
	div rcx
	; get the digits
	mov rcx , 10
	xor rdx , rdx
	div rcx
	mov [timing_text+6] , dl
	xor rdx , rdx
	div rcx
	mov [timing_text+5] , dl
	xor rdx , rdx
	div rcx
	mov [timing_text+4] , dl
	xor rdx , rdx
	div rcx
	mov [timing_text+2] , dl
	xor rdx , rdx
	div rcx
	mov [timing_text+1] , dl
	xor rdx , rdx
	div rcx
	mov [timing_text] , dl
	; TODO display time with font on screen
	ret





;	mov edx , 0x00ffffff		; 0x00ffffff is white
;	mov esi , [X11_graphics_context]
;	mov rdi , [X11_display]
;	call XSetForeground

;	mov eax , 0			
;	push rax			; padding to align the stack to 16 bytes
;	mov eax , 20
;	push rax
;	mov r9d , 180
;	mov r8d , 60
;	mov ecx , 10
;	mov edx , [X11_graphics_context]
;	mov esi , [X11_window]
;	mov rdi , [X11_display]
;	call XDrawLine
