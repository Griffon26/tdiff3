/* This header is a stub */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#undef MIN
#undef MAX
#define MIN(a, b) ((a) <= (b) ? (a) : (b))
#define MAX(a, b) ((a) >= (b) ? (a) : (b))


typedef ptrdiff_t lin;
#define LIN_MAX PTRDIFF_MAX
