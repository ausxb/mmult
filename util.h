#pragma once

/*
 * The matrix multiplication kernels perform the multiplication BA
 * on a matrix B of size (m, k) and a matrix A of size (k, n). The
 * elements of the matrix are assumed to be stored in row major order.
 * The result is stored in row major order in c.
 */

extern void kern1(
	unsigned __int64 m,
	unsigned __int64 k,
	unsigned __int64 n,
	double *c,
	const double *b,
	const double *a
);

extern void kern2(
	unsigned __int64 m,
	unsigned __int64 k,
	unsigned __int64 n,
	double *c,
	const double *b,
	const double *a
);

extern void kern3(
	unsigned __int64 m,
	unsigned __int64 k,
	unsigned __int64 n,
	double *c,
	const double *b,
	const double *a
);

void kern_refR(
	unsigned __int64 m,
	unsigned __int64 k,
	unsigned __int64 n,
	double *c,
	const double *b,
	const double *a
);

void kern_refC(
	unsigned __int64 m,
	unsigned __int64 k,
	unsigned __int64 n,
	double *c,
	const double *b,
	const double *a
);

void fillRandomDoubles(unsigned len, double *ptr);

void fillSequential(unsigned len, double *ptr);

void printMatrix(const char *fmt, unsigned m, unsigned n, double *ptr);

void verify_compute_kernels(unsigned __int64 m, unsigned __int64 k, unsigned __int64 n);

void run_fixed_tests();

int cmp(unsigned len, const double *m1, const double *m2);