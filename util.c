#include <stdio.h>
#include <stdlib.h>
#include "util.h"

#define TEST_CASE_KFUNC(fn) fn(m, k, n, result, B, A); \
printf("%-9s: ", #fn); \
if(cmp(m * n, solution, result) == 0) \
	printf("match\n");


void kern_refR(unsigned __int64 m, unsigned __int64 k, unsigned __int64 n, double *c, const double *b, const double *a)
{
	for(unsigned __int64 p = 0; p < m; p++)
	{
		for(unsigned __int64 q = 0; q < n; q++)
		{
			double sum = 0.0;
			for(unsigned __int64 r = 0; r < k; r++)
			{
				sum += b[p * k + r] * a[r * n + q];
			}
			c[p * n + q] = sum;
		}
	}
}

void kern_refC(unsigned __int64 m, unsigned __int64 k, unsigned __int64 n, double *c, const double *b, const double *a)
{
	for(unsigned __int64 p = 0; p < m; p++)
	{
		//for(unsigned __int64 t = 0; t < n; t++)
		//	c[p * n + t] = 0;
		
		for(unsigned __int64 q = 0; q < k; q++)
		{
			double s = b[p * k + q];
			for(unsigned __int64 r = 0; r < n; r++)
			{
				c[p * n + r] += s * a[q * n + r];
			}
		}
	}
}

void fillRandomDoubles(unsigned len, double *ptr)
{
	while(len > 0)
		ptr[--len] = (double)rand() / (double)RAND_MAX;
}

void fillSequential(unsigned len, double *ptr)
{
	while(len > 0)
		ptr[--len] = (double)len;
}

void printMatrix(const char *fmt, unsigned m, unsigned n, double *ptr)
{
	for(unsigned r = 0; r < m; r++)
	{
		for(unsigned c = 0; c < n; c++)
		{
			printf(fmt, ptr[r * n + c]);
			if(c != n - 1) putc(' ', stdout);
			else putc('\n', stdout);
		}
	}
}

void verify_compute_kernels(unsigned __int64 m , unsigned __int64 k, unsigned __int64 n)
{
	double *B = malloc(m * k * sizeof(double));
	double *A = malloc(k * n * sizeof(double));
	double *reference = malloc(m * n * sizeof(double));
	double *result = malloc(m * n * sizeof(double));
	
	fillSequential(m * k, B);
	fillSequential(k * n, A);
	
	kern_refR(m, k, n, reference, B, A);
	kern1(m, k, n, result, B, A);
	
	printf("B:\n");
	printMatrix("%5.f", m, k, B);
	printf("A:\n");
	printMatrix("%5.f", k, n, A);
	
	if(cmp(m * n, reference, result) == 0)
	{
		printf("Match\n");
		printf("Result:\n");
		printMatrix("%11.f", m, n, result);
	}
	else
	{
		printf("Mismatch\n");
		printf("Reference:\n");
		printMatrix("%a", m, n, reference);
		printf("Result:\n");
		printMatrix("%a", m, n, result);
	}
	
	free(result); free(reference); free(A); free(B);
}

void run_fixed_tests()
{
	unsigned __int64 m, k, n;
	double *B, *A, *solution, *result;
	int num = 0, status = 0;
	
	FILE *testfile;
	testfile = fopen("test_cases.txt", "r");
	
	if(!testfile)
	{
		perror("Could not open test_cases.txt");
		return;
	}
	
	while(status != EOF)
	{
		status = fscanf(testfile, "%zu %zu %zu", &m, &k, &n);
		
		if(status != EOF)
		{
			/*
				4 minus column size mod 4 gives the number of elements of padding
				required so that kern2 writes to valid memory 
			*/
			B = malloc(m * k * sizeof(double));
			A = malloc((k * n + 4 - n % 4) * sizeof(double));
			solution = malloc(m * n * sizeof(double));
			result = malloc((m * n + 4 - n % 4) * sizeof(double));
			// If any of the allocations returned NULL, aw shucks...
			
			for(unsigned u = 0; u < m * k; u++) status = fscanf(testfile, "%lf", B + u);
			for(unsigned u = 0; u < k * n; u++) status = fscanf(testfile, "%lf", A + u);
			for(unsigned u = 0; u < m * n; u++) status = fscanf(testfile, "%lf", solution + u);
			
			printf("## Test %d: %zux%zu and %zux%zu ##\n", num, m, k, k, n);
			TEST_CASE_KFUNC(kern_refR)
			memset(result, 0, (m * n + 4 - n % 4) * sizeof(double));
			TEST_CASE_KFUNC(kern_refC)
			TEST_CASE_KFUNC(kern1)
			TEST_CASE_KFUNC(kern2)
			printf("## Test %d: %zux%zu and %zux%zu ##\n\n", num, m, k, k, n);
			
			free(result); free(solution); free(A); free(B);
		}
		
		num++;
	}
	
	fclose(testfile);
}

int cmp(unsigned len, const double *m1, const double *m2)
{
	for(unsigned u = 0; u < len; u++)
	{
		if(m1[u] != m2[u])
		{
			printf("index %u, %f != %f\n", u, m1[u], m2[u]);
			return 1;
		}
	}
	return 0;
}