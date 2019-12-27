; Register usage
; r9: base address of C
; r10: base address of B
; r11: base address of A
; rcx: row counter/index for m_loop
; rdx: inner loop counter for k_loop
; r8: column counter/index for n_loop, column displacement for A
; rax: primarily load address from B, used in other calculations
; rbx: primarily load address from A, used in other calculations
; ymm0: running sum for four columns of A multiplied by the
; 		corresponding element from a row of B
; ymm1: stores an element from a row of B broadcasted as four
; 		packed doubles and used to multiply rows of B with columns of A

_TEXT SEGMENT

; rbx saved in first 8 bytes
_ksc = 8 ; "k scaled", i.e. k * 8
_nsc = 16 ; "n scaled", i.e. n * 8
; return address resides at rsp + 24
_m = 32
_k = 40
_n = 48
_c = 56
_b = 64
_a = 72

; kern2 PROTO m:QWORD, k:QWORD, n:QWORD, c:QWORD, b:QWORD, a:QWORD

kern2 PROC PUBLIC FRAME
	mov	QWORD PTR [rsp+32], r9 ; c
	mov	QWORD PTR [rsp+24], r8 ; n
	mov	QWORD PTR [rsp+16], rdx ; k
	mov	QWORD PTR [rsp+8], rcx ; m
	sub rsp, 24
	mov QWORD PTR [rsp], rbx
	.savereg rbx, 0
	.endprolog
	
	shl rdx, 3 ; k * 8
	mov _ksc[rsp], rdx
	shl r8, 3 ; n * 8
	mov _nsc[rsp], r8
	
	mov r10, QWORD PTR _b[rsp]
	mov r11, QWORD PTR _a[rsp]
	
	mov rcx, 0
	mov rdx, 0
	mov rbx, 0
	mov r8, 0
	
m_loop:
	cmp rcx, QWORD PTR _m[rsp]
	jnb m_term
	
	mov r8, 0
	
n_loop:
	cmp r8, _n[rsp]
	jnb n_term
	
	; Store address of first element in row 'rcx' of B
	; found at r10 + rcx * k * 8
	mov rax, rcx
	mul QWORD PTR _ksc[rsp]
	add rax, r10
	
	; Offset rbx from base address of A by 'r8' elements (for stride n, columnwise loop)
	; given by r11 + r8 * 8
	; Stores address of element in first row, column 'r8' of A
	mov rbx, r8
	shl rbx, 3
	add rbx, r11
	
	mov rdx, 0
	vpxor ymm0, ymm0, ymm0
	
k_loop:
	cmp rdx, QWORD PTR _k[rsp]
	jnb k_term
	
	; Load element of B in row 'rcx' and column 'rdx'
	vbroadcastsd ymm1, QWORD PTR [rax]
	vfmadd231pd ymm0, ymm1, YMMWORD PTR [rbx] ; May be an unaligned load
	
	add rbx, _nsc[rsp] ; Increment address by column stride to point to next row
	add rax, 8
	inc rdx
	jmp k_loop
	
k_term:
	mov rax, rcx ; Repurpose rax, rbx to calculate write address
	mul QWORD PTR _nsc[rsp]
	add rax, r9
	vmovupd YMMWORD PTR [rax + r8 * 8], ymm0 ; r9 + rcx * n * 8 + r8 * 8

	add r8, 4
	jmp n_loop
	
n_term:
	inc rcx
	jmp m_loop
	
m_term:
	mov rbx, QWORD PTR [rsp]
	add rsp, 24
	xor rax, rax
	ret
kern2 ENDP

_TEXT ENDS

END