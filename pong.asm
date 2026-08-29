; Pong in ASM
; written in fasm: https://flatassembler.net/
;
; useful docs :
; https://flatassembler.net/docs.php?article=manual for the general fasm syntax (for using the default macros of fasm)
; https://flatassembler.net/docs.php?article=fasmg_manual for the macro syntax (the programming langage on which
;	the macros are defined)
; https://refspecs.linuxfoundation.org/elf/x86_64-abi-0.99.pdf (chapter A.2 AMD64 Linux Kernel Conventions for
; 	for syscalls and user-level applications)
;
; fasm2 pong.asm
; mold -o pong pong.o --dynamic-linker=/lib64/ld-linux-x86-64.so.2 --library-path=/usr/lib64 -lGL -lglfw
;


format ELF64

iterate extern_name,\
	glfwInit, glfwTerminate, glfwCreateWindow, glfwMakeContextCurrent,\
	glfwWindowShouldClose, glClearColor, glClear, glfwSwapBuffers, glfwPollEvents,\
	glBegin, glEnd, glFlush, glViewport, glColor3f, glVertex2f, glfwGetFramebufferSize,\
	
	extrn extern_name 
end iterate

macro linux_syscall number*, args&
	mov rax,number
	iterate arg, args
		if 1=%
			mov rdi,arg
		else if 2=%
			mov rsi,arg
		else if 3=%
			mov rdx,arg
		else if 4=%
			mov r10,arg
		else if 5=%
			mov r8,arg
		else if 6=%
			mov r9,arg
		else
			assert 0 > %% ; too many arguments
		end if
	end iterate 
	syscall
end macro

macro linux_syscall_exit exit_code
	linux_syscall 60, exit_code
end macro

macro linux_fn_call name*, args& 
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
			assert 0 > %% ; too many arguments
		end if
	end iterate 
	call name
end macro

; TODO: get them from the libraries?
GL_COLOR_BUFFER_BIT := 0x00004000
GL_TRIANGLES := 0x0004

section '.rodata' 
title:	db "Pong in ASM", 0

section '.bss' writeable
label window:qword
	rq 1
label width:dword
	rd 1
label height:dword
	rd 1

section '.text' executable
public _start ; make _start available to the linker (if it is not public the name is not kept)
_start:
	linux_fn_call glfwInit
	
	linux_fn_call glfwCreateWindow,500,600,title,0,0
	mov [window],rax

	linux_fn_call glfwMakeContextCurrent,[window]
	
	; clear color values	
	mov r12d,0.0
	mov r13d,0.4

	movq xmm0,r12; r
	movq xmm1,r12 ; g
	movq xmm2,r13 ; b
	movq xmm3,r12 ; a
	call glClearColor


mainLoop:
	mov rdi,[window]
	lea rsi,[width]
	lea rdx,[height]
	call glfwGetFramebufferSize
	
	mov rdi,0
	mov rsi,0
	mov edx,[width]
	mov ecx,[height]
	call glViewport

	linux_fn_call glClear,GL_COLOR_BUFFER_BIT

	linux_fn_call glBegin,GL_TRIANGLES

	; loop floats
	mov r13d,1.0
	mov r14d,-1.0

	movq xmm0, r13
	movq xmm1, r12
	movq xmm2, r12
	call glColor3f

	movq xmm0, r14
	movq xmm1, r14
	call glVertex2f

	movq xmm0, r12
	movq xmm1, r13
	movq xmm2, r12
	call glColor3f

	movq xmm0, r13
	movq xmm1, r14
	call glVertex2f

	movq xmm0, r12
	movq xmm1, r12
	movq xmm2, r13
	call glColor3f
	
	movq xmm0, r12
	movq xmm1, r13
	call glVertex2f
	
	linux_fn_call glEnd

	linux_fn_call glfwSwapBuffers,[window]

	linux_fn_call glfwPollEvents

	linux_fn_call glfwWindowShouldClose,[window]

	cmp rax,0
	je mainLoop

	linux_fn_call glfwTerminate

	linux_syscall_exit 0 

	





