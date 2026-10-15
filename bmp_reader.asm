; fasm2 bpm_reader.asm
; mold -o bmp_reader bmp_reader.o
; 
; output format : 
;	img_format u32 = 0
;	img_widht u32
;	img_height u32
;	color[img_widht*img_height] (with img top left = [0,0]
; output color format 0x00RRGGBB
;
; bmp reference https://www.ece.ualberta.ca/~elliott/ee552/studentAppNotes/2003_w/misc/bmp_file_format/bmp_file_format.htm
; INFO_bits_per_pixel:
; 1 = monochrome palette. NumColors = 1  
; 4 = 4bit palletized. NumColors = 16  
; 8 = 8bit palletized. NumColors = 256 
; 16 = 16bit RGB. NumColors = 65536
; 24 = 24bit RGB. NumColors = 16M
;
; INFO_compression:
; 0 = no compression  
; 1 = 8bit RLE encoding  
; 2 = 4bit RLE encoding


format ELF64

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

syscall_read	:= 0
syscall_open 	:= 2
syscall_lseek	:= 8
SEEK_SET 	:= 0
SEEK_CUR 	:= 1
SEEK_END 	:= 2


max_pixels		:= 10_000_000

section '.rodata' 
section '.data' writeable 
section '.bss' writeable
label output_format_version	: dword ; just in case there is need to be able to change the format without breaking everything
		rd 1
label output_img_width		: dword
		rd 1
label output_img_height		: dword
		rd 1
label output_pixel_data		: dword ; 0x00RRGGBB (output image)
		rd max_pixels 

; bmp related data
align 8
label bmp_file_name_ptr		: qword	; ptr to file name string from the cmdline arguments
	rq 1
label bmp_pixel_data_ptr	: qword ; (to initiallize) ptr to the pixel data in the opened file 
	rq 1
label bmp_file_name_len		: dword	; len of file name string
	rd 1
label bmp_file_descriptor	: dword 
	rd 1
label bmp_num_colors		: dword	; (to initialize)
	rd 1
label bmp_file_size		: dword
	rd 1
; bmp file
align 8
	rb 2			; to align the file data to 8 bytes, at it starts with 2 bytes and then some dwords
bmp_file_data: 
bmp_header:				;14 bytes
label bmp_H_signature		: word	; = 'BM'
	rw 1
label bmp_H_file_size		: dword	; in bytes
	rd 1
ilabel bmp_H_reserved		: dword ; unused = 0
	rd 1
label bmp_H_data_offset		: dword ; offset of the bitmap data
	rd 1
end_bmp_header:
assert (bmp_header + 14 = end_bmp_header)

bmp_info_header:			; 40 bytes
label bmp_IH_size_offset	: dword ; size of the InfoHeader = 40
	rd 1
label bmp_IH_width		: dword ; width of the bitmap (pixels)
	rd 1
label bmp_IH_height		: dword ; height of the bitmap (pixels)
	rd 1
label bmp_IH_planes		: word 	; number of planes = 1
	rw 1
label bmp_IH_bits_per_pixel	: word	; see INFO_bits_per_pixel
	rw 1
label bmp_IH_compression	: dword ; see INFO_compression  TODO support RLEs
	rd 1
label bmp_IH_image_size		: dword ; compressed image size
	rd 1
label bmp_IH_x_ppm		: dword ; pixels per meter (horizontal)
	rd 1
label bmp_IH_y_ppm		: dword ; pixels per meter (vertical)
	rd 1
label bmp_IH_colors_used	: dword
	rd 1
label bmp_IH_important_colors	: dword
	rd 1
end_bmp_info_header:
assert bmp_info_header + 40 = end_bmp_info_header

bmp_color_table:			; present if bits_per_pixel <= 8
; bmp_color_table_size := 4 * bmp_num_colors
; 	red = 1 bytes
; 	green = 1 bytes
; 	blue = 1 bytes
; 	reserved = 1 bytes
; repeted bmp_num_colors times
;
; Pixel data size : bmp_IH_image_size

	rb max_pixels 
end_bmp_file_data:
bmp_file_max_size := end_bmp_file_data - bmp_file_data


section '.text' executable
public _start ; make _start available to the linker (if it is not public the name is not kept)
_start:
	pop r8		; the arguments to main are passed on the stack (argc & argv(all the pointers to the strings))
	cmp r8 , 2
	jne exit1
	pop rsi 	; ignore the executable name

	pop rsi		; first filename argument

	xor rax , rax	; count the number of chars in string
	dec rax
.count:	
	inc rax
	mov bl , [rsi+rax]
	cmp bl , 0
	jne .count 
	mov [bmp_file_name_len] , eax
	mov [bmp_file_name_ptr] , rsi
	
	mov rdx , 0
	mov rsi , 0
	mov rdi , [bmp_file_name_ptr]
	linux_syscall syscall_open		; open
	cmp eax, 0
	jl exit_errno
	mov [bmp_file_descriptor] , eax

	mov rdx , SEEK_END
	mov rsi , 0				; offset
	mov edi , [bmp_file_descriptor]
	linux_syscall syscall_lseek
	cmp eax, 0
	jl exit_errno
	cmp eax, bmp_file_max_size
	jg exit254
	mov [bmp_file_size] , eax

	mov rdx , SEEK_SET
	mov rsi , 0
	mov edi , [bmp_file_descriptor]
	linux_syscall syscall_lseek
	cmp eax, 0
	jl exit_errno

	mov edx , [bmp_file_size]
	lea rsi , [bmp_file_data]
	mov edi , [bmp_file_descriptor]
	linux_syscall syscall_read		; read
	cmp eax, 0
	jl exit_errno

	mov ax , [bmp_H_signature]
	cmp ax , 'BM'
	jnz exit255

	mov eax , [bmp_file_size]
	cmp eax , [bmp_H_file_size]
	jnz exit253

	lea rax , [bmp_file_data]
	add rax , [bmp_H_data_offset]
	mov [bmp_pixel_data_ptr] , rax

	mov eax , [bmp_IH_width]
	mov [output_img_width] , eax
	mov eax , [bmp_IH_height]
	mov [output_img_height] , eax

	mov cx , [bmp_IH_bits_per_pixel]
	mov eax , 1
	shl eax , cl
	mov [bmp_num_colors] , eax
	



	
exit0:
	linux_syscall_exit 0
exit1:
	linux_syscall_exit 1
exit2:
	linux_syscall_exit 2
exit3:
	linux_syscall_exit 3
exit4:
	linux_syscall_exit 4
exit253:
	linux_syscall_exit 253 ; bmp file size and declared size in the header not matching
exit254:
	linux_syscall_exit 254 ; bmp file too big for the current settings, need to change bmp_file_max_size
exit255:
	linux_syscall_exit 255
exit_errno:
	neg eax
	linux_syscall_exit rax
