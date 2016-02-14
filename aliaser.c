#include <stdint.h>

typedef union {
  int64_t i;
  double d;
} ID;

// XXX: this is technically undefined behavior
// and might break on some obscure compiler

double i2f(int64_t i) {
  ID x;
  x.i = i;
  return x.d;
}

int64_t f2i(double d) {
  ID x;
  x.d = d;
  return x.i;
}
