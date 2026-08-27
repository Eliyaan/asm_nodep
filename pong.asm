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

macro linux_syscall number*, rdi_val, rsi_val, rdx_val, r10_val, r8_val, r9_val
	mov rax,number
	match ,rdi_val
		mov rdi,rdi_val
		match ,rsi_val
			mov rsi,rsi_val
			match ,rdx_val
				mov rdx,rdx_val
				match ,r10_val
					mov r10,r10_val
					match ,r8_val
						mov r8,r8_val
						match ,r9_val
							mov r9,r9_val
						end match
					end match
				end match
			end match
		end match
	end match
	syscall
end macro

macro linux_syscall_exit exit_code
	linux_syscall 60, exit_code
end macro

macro linux_fn_call name*, rdi_val, rsi_val, rdx_val, rcx_val, r8_val, r9_val
	if ~ `rdi_val eq ''
		mov rdi,rdi_val
		if ~ `rsi_val eq ''
			mov rsi,rsi_val
			if ~ `rdx_val eq '' 
				mov rdx,rdx_val
				if ~ `rcx_val eq '' 
					mov rcx,rcx_val
					if ~ `r8_val eq '' 
						mov r8,r8_val
						if ~ `r9_val eq '' 
							mov r9,r9_val
						end if
					end if
				end if
			end if
		end if
	end if
	call name
end macro

; TODO: get them from the libraries?
GL_COLOR_BUFFER_BIT := 0x00004000
GL_TRIANGLES := 0x0004

section '.rodata' 
title:	db "Pong in ASM", 0

section '.bss' writeable
window: rq 1
width: rd 1
height: rd 1

section '.text' executable
public _start ; make _start available to the linker (if it is not public the name is not kept)
_start:
	linux_fn_call glfwInit
	
	linux_fn_call glfwCreateWindow,800,600,title,0,0
	mov [window],rax

	linux_fn_call glfwMakeContextCurrent,[window]
	
	; clear color values	
	mov r12,0.0
	mov r13,0.4

	movq xmm0,r12 ; r
	movq xmm1,r12 ; g
	movq xmm2,r13 ; b
	movq xmm3,r12 ; a
	call glClearColor

	; loop floats
	mov r13,1.0
	mov r14,-1.0

mainLoop:
	linux_fn_call glfwGetFramebufferSize,[window],[width],[height]
	
	linux_fn_call glViewport,0,0,[width],[height]

	linux_fn_call glClear,GL_COLOR_BUFFER_BIT

	linux_fn_call glBegin,GL_TRIANGLES

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

	





