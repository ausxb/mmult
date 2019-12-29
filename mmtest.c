/*
 * Compile via the following commands:
 *
 * ml64 /c /Zi /Zd kern1.asm
 * ml64 /c /Zi /Zd kern2.asm
 * ml64 /c /Zi /Zd kern3.asm
 * cl /arch:AVX2 /fp:fast /MDd /Zi mmtest.c util.c /link /DEBUG:FULL kern1.obj kern2.obj kern3.obj
 * 
 * Remove /Zi, /Zd, /DEBUG:FULL, and change /MDd to /MD for non-debug
 */
#include <stdio.h>
#include <stdlib.h>
#include <Windows.h> // QPC facilities
#include "util.h"

#define MATRIX_SIZE 303
#define ITERATIONS 50

static const unsigned rseed = 0x02560256;
static const char *ker_names[] = { "refR", "refC", "kern1", "kern2", "kern3" };

// (4 - MATRIX_SIZE % 4 ) * 8 bytes of padding necessary
// at end of buffer required for kern2
static const unsigned __int64 bytes = 
	(MATRIX_SIZE * MATRIX_SIZE + 4 - MATRIX_SIZE % 4) * sizeof(double);

int main(int argc, char *argv[])
{
	LARGE_INTEGER freq, start, end;
	LONGLONG avg[5] = { 0 };
	
	QueryPerformanceFrequency(&freq);
	
	srand(rseed);
	
	// verify_compute_kernels(32, 32, 32);
	// putc('\n', stdout);
	run_fixed_tests();

	double *B = malloc(bytes);
	double *A = malloc(bytes);
	double *C = malloc(bytes); // C = BA
	
	printf("Timing multiplication of two %ux%u matrices\n", MATRIX_SIZE, MATRIX_SIZE);
	
	for(int i = 0; i < ITERATIONS; i++)
	{
		// Overwrite cached matrix values
		fillRandomDoubles(MATRIX_SIZE * MATRIX_SIZE, B);
		fillRandomDoubles(MATRIX_SIZE * MATRIX_SIZE, A);
		
		memset(C, 0, MATRIX_SIZE * MATRIX_SIZE * sizeof(double));
		
		QueryPerformanceCounter(&start);
		kern_refR(MATRIX_SIZE, MATRIX_SIZE, MATRIX_SIZE, C, B, A);
		QueryPerformanceCounter(&end);
		avg[0] += end.QuadPart - start.QuadPart;
		
		memset(C, 0, MATRIX_SIZE * MATRIX_SIZE * sizeof(double));
		
		QueryPerformanceCounter(&start);
		kern_refC(MATRIX_SIZE, MATRIX_SIZE, MATRIX_SIZE, C, B, A);
		QueryPerformanceCounter(&end);
		avg[1] += end.QuadPart - start.QuadPart;
		
		memset(C, 0, MATRIX_SIZE * MATRIX_SIZE * sizeof(double));
		
		QueryPerformanceCounter(&start);
		kern1(MATRIX_SIZE, MATRIX_SIZE, MATRIX_SIZE, C, B, A);
		QueryPerformanceCounter(&end);
		avg[2] += end.QuadPart - start.QuadPart;
		
		memset(C, 0, MATRIX_SIZE * MATRIX_SIZE * sizeof(double));
		
		QueryPerformanceCounter(&start);
		kern2(MATRIX_SIZE, MATRIX_SIZE, MATRIX_SIZE, C, B, A);
		QueryPerformanceCounter(&end);
		avg[3] += end.QuadPart - start.QuadPart;
		
		memset(C, 0, MATRIX_SIZE * MATRIX_SIZE * sizeof(double));
		
		QueryPerformanceCounter(&start);
		kern3(MATRIX_SIZE, MATRIX_SIZE, MATRIX_SIZE, C, B, A);
		QueryPerformanceCounter(&end);
		avg[4] += end.QuadPart - start.QuadPart;
	}
	
	printf("Average of %d iterations\n", ITERATIONS);
	for(int i = 0; i < 5; i++)
		printf("\t%-5s: %15.4f ticks\n", ker_names[i], (double)avg[i] / ITERATIONS);
	
	free(C); free(A); free(B);
	
	return 0;
}