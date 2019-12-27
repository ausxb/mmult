; Register usage
; r9: base address of C
; r10: base address of B
; r11: base address of A
; rcx: row counter/index for m_loop
; rdx: inner loop counter for k_loop
; r8: column counter/index for n_loop, column displacement for A
; rax: primarily load address from B, used in other calculations
; rbx: primarily load address from A, used in other calculations
; r12: used to transfer between A, staging buffer, and C in nterm_loop
; ymm0: running sum for four columns of A multiplied by the
; 		corresponding element from a row of B
; ymm1: stores an element from a row of B broadcasted as four
; 		packed doubles and used to multiply rows of B with columns of A

_TEXT SEGMENT

; first 32 bytes above rsp are a staging buffer
; for loading remaining columns on right of A

_mrc = 32 ; Stores the remaining columns of A after n_loop
_r12save = 40 ; r12 saved by callee
_rbxsave = 48 ; rbx saved by callee
_ksc = 56 ; "k scaled", i.e. k * 8
_nsc = 64 ; "n scaled", i.e. n * 8
; return address resides at rsp + 72
_m = 80
_k = 88
_n = 96
_c = 104
_b = 112
_a = 120

; kern1 PROTO m:QWORD, k:QWORD, n:QWORD, c:QWORD, b:QWORD, a:QWORD

kern1 PROC PUBLIC FRAME
	mov	QWORD PTR [rsp+32], r9 ; c
	mov	QWORD PTR [rsp+24], r8 ; n
	mov	QWORD PTR [rsp+16], rdx ; k
	mov	QWORD PTR [rsp+8], rcx ; m
	sub rsp, 72
	mov QWORD PTR _rbxsave[rsp], rbx
	.savereg rbx, _rbxsave
	mov QWORD PTR _r12save[rsp], r12
	.savereg rbx, _r12save
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
	mov [rsp + 24], r8
	
m_loop:
	cmp rcx, QWORD PTR _m[rsp]
	jnb m_term
	
	mov r8, 0
	
n_loop:
	mov rax, QWORD PTR _n[rsp]
	sub rax, r8
	cmp rax, 4
	jb n_term
	
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
	test rax, rax ; rax = n - r8 (which is < 4 at this point)
	jz n_exit ; no remaining columns in A
	mov _mrc[rsp], rax
	
	; Set rax and rbx to addresses as in n_loop above
	mov rax, rcx
	mul QWORD PTR _ksc[rsp]
	add rax, r10
	mov rbx, r8
	shl rbx, 3
	add rbx, r11
	
	mov rdx, 0
	vpxor ymm0, ymm0, ymm0
nterm_loop:
	cmp rdx, QWORD PTR _k[rsp]
	jnb nterm_write
	
	vbroadcastsd ymm1, QWORD PTR [rax]
	
	; Buffer remainder of row 'rdx' from A in scratch space
	mov r12, [rbx] ; At least one remaining column
	mov [rsp], r12
	cmp QWORD PTR _mrc[rsp], 2
	jb nterm_fma
	mov r12, [rbx + 8]
	mov [rsp + 8], r12
	cmp QWORD PTR _mrc[rsp], 3
	jb nterm_fma
	mov r12, [rbx + 16]
	mov [rsp + 16], r12
	
nterm_fma:
	vfmadd231pd ymm0, ymm1, YMMWORD PTR [rsp]
	add rbx, _nsc[rsp]
	add rax, 8
	inc rdx
	jmp nterm_loop
	
nterm_write:
	; Same write routine as above
	vmovupd [rsp], ymm0
	
	mov rax, rcx
	mul QWORD PTR _nsc[rsp]
	add rax, r9
	lea rbx, [rax + r8 * 8] ; rbx = r9 + rcx * n * 8 + r8 * 8
	
	; Note rsp and rbp are switch from above to write from buffer to C
	mov r12, [rsp]
	mov [rbx], r12
	cmp QWORD PTR _mrc[rsp], 2
	jb n_exit
	mov r12, [rsp + 8]
	mov [rbx + 8], r12
	cmp QWORD PTR _mrc[rsp], 3
	jb n_exit
	mov r12, [rsp + 16]
	mov [rbx + 16], r12
	
n_exit:
	inc rcx
	jmp m_loop
	
m_term:

	mov r12, QWORD PTR _r12save[rsp]
	mov rbx, QWORD PTR _rbxsave[rsp]
	add rsp, 72
	xor rax, rax
	ret
kern1 ENDP

_TEXT ENDS

END