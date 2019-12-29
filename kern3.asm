; Register usage
; r9: row base address in C
; r10: read address in B
; r11: read address in A
; rcx: row counter/index for m_loop
; rbx: counter/index for k_loop
; r8: column counter/index for n_loop
; rax: used in calculations
; ymm0: loads elements of a row from A and used as
;		output register for AVX calculations
; ymm1: stores an element from a row of B broadcasted as four
; 		packed doubles and used to multiply rows of B with columns of A

_TEXT SEGMENT

; first 64 bytes above rsp are a staging buffer
; for loading remainder of rows in A and C

_mrc = 64 ; Stores the remaining columns of A after n_loop
_rbxsave = 72 ; rbx saved by callee
_ksc = 80 ; "k scaled", i.e. k * 8
_nsc = 88 ; "n scaled", i.e. n * 8
; return address resides at rsp + 96
_m = 104
_k = 112
_n = 120
_c = 128
_b = 136
_a = 144

; kern3 PROTO m:QWORD, k:QWORD, n:QWORD, c:QWORD, b:QWORD, a:QWORD

kern3 PROC PUBLIC FRAME
	mov	QWORD PTR [rsp+32], r9 ; c
	mov	QWORD PTR [rsp+24], r8 ; n
	mov	QWORD PTR [rsp+16], rdx ; k
	mov	QWORD PTR [rsp+8], rcx ; m
	sub rsp, 96
	mov QWORD PTR _rbxsave[rsp], rbx
	.savereg rbx, _rbxsave
	.endprolog
	
	shl rdx, 3
	mov _ksc[rsp], rdx
	shl r8, 3
	mov _nsc[rsp], r8

	mov rcx, 0
	
m_loop:
	cmp rcx, QWORD PTR _m[rsp]
	jnb m_term
	
	; r10 = _b[rsp] + rcx * k * 8
	; Points to first element of row 'rcx' in B
	mov rax, rcx
	mul QWORD PTR _ksc[rsp]
	mov r10, _b[rsp]
	add r10, rax
	
	; r9 = _c[rsp] + rcx * n * 8
	mov rax, rcx
	mul QWORD PTR _nsc[rsp]
	mov r9, _c[rsp]
	add r9, rax
	
	mov rbx, 0
	
	; First iteration of k should store
	; directly instead of load a partially
	; computed row, containing garbage on first iteration
	cmp rbx, QWORD PTR _k[rsp]
	jnb k_term
	vbroadcastsd ymm1, QWORD PTR [r10]
	mov r11, _a[rsp]
	mov r8, 0
	
n_preloop:
	mov rax, QWORD PTR _n[rsp]
	sub rax, r8
	cmp rax, 4
	jb n_preterm
	
	vmulpd ymm0, ymm1, YMMWORD PTR [r11]
	vmovupd YMMWORD PTR [r9 + r8 * 8], ymm0

	add r11, 32
	add r8, 4
	jmp n_preloop

	; Since rbx is zero at this point, the following instructions clear
	; the output location in C. The instructions at n_term can be used
	; as usual to handle remaining elements in the first row of A.
n_preterm:
	cmp rax, 1
	jb n_term
	mov [r9 + r8 * 8], rbx
	cmp rax, 2
	jb n_term
	mov [r9 + r8 * 8 + 8], rbx
	cmp rax, 3
	jb n_term
	mov [r9 + r8 * 8 + 16], rbx
	jmp n_term
	
k_loop:
	cmp rbx, QWORD PTR _k[rsp]
	jnb k_term
	
	vbroadcastsd ymm1, QWORD PTR [r10]
	
	; r11 = _a[rsp] + rbx * n * 8
	; Points to first element of row 'rbx' in A
	mov rax, rbx
	mul QWORD PTR _nsc[rsp]
	mov r11, _a[rsp]
	add r11, rax
	
	mov r8, 0
	
n_loop:
	mov rax, QWORD PTR _n[rsp]
	sub rax, r8
	cmp rax, 4
	jb n_term
	
	vmovupd ymm0, YMMWORD PTR [r11]
	vfmadd213pd ymm0, ymm1, YMMWORD PTR [r9 + r8 * 8]
	vmovupd YMMWORD PTR [r9 + r8 * 8], ymm0

	add r11, 32
	add r8, 4
	jmp n_loop
	
n_term:
	test rax, rax
	jz n_exit ; no remaining elements in row
	mov _mrc[rsp], rax
	
	; Buffer remainder of row 'rbx' from A in scratch space
	; There is least one remaining element if this location is reached
	mov rdx, [r11] 
	mov [rsp], rdx
	mov rdx, [r9 + r8 * 8]
	mov [rsp + 32], rdx
	cmp QWORD PTR _mrc[rsp], 2
	jb nterm_fma
	mov rdx, [r11 + 8]
	mov [rsp + 8], rdx
	mov rdx, [r9 + r8 * 8 + 8]
	mov [rsp + 40], rdx
	cmp QWORD PTR _mrc[rsp], 3
	jb nterm_fma
	mov rdx, [r11 + 16]
	mov [rsp + 16], rdx
	mov rdx, [r9 + r8 * 8 + 16]
	mov [rsp + 48], rdx
	
nterm_fma:
	; rsp[0:32] contains remainder of row in A
	; rsp[32:64] contains remainder of partially calculated row from C
	vmovupd ymm0, YMMWORD PTR [rsp]
	vfmadd213pd ymm0, ymm1, YMMWORD PTR [rsp + 32]
	vmovupd YMMWORD PTR [rsp + 32], ymm0
	
	mov rdx, [rsp + 32]
	mov [r9 + r8 * 8], rdx
	cmp QWORD PTR _mrc[rsp], 2
	jb n_exit
	mov rdx, [rsp + 40]
	mov [r9 + r8 * 8 + 8], rdx
	cmp QWORD PTR _mrc[rsp], 3
	jb n_exit
	mov rdx, [rsp + 48]
	mov [r9 + r8 * 8 + 16], rdx

n_exit:
	add r10, 8
	inc rbx
	jmp k_loop

k_term:
	inc rcx
	jmp m_loop
	
m_term:
	mov rbx, QWORD PTR _rbxsave[rsp]
	add rsp, 96
	xor rax, rax
	ret
kern3 ENDP

_TEXT ENDS

END