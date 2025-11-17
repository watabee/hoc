#include <stdlib.h>
#include <math.h>
#include <errno.h>

extern void execerror(const char *s, const char *t);
extern int errno;

// check result of library call
double errcheck(double d, char *s) {
    if (errno == EDOM) {
        errno = 0;
        execerror(s, "argument out of domain");
    } else if (errno == ERANGE) {
        errno = 0;
        execerror(s, "result out of range");
    }
    return d;
}

double Rand() {
	return (double)rand() / RAND_MAX;
}

double Atan2(double x, double y) {
    return errcheck(atan2(y, x), "atan2");
}

double Log(double x) {
    return errcheck(log(x), "log");
}

double Log10(double x) {
    return errcheck(log10(x), "log10");
}

double Exp(double x) {
    return errcheck(exp(x), "exp");
}

double Sqrt(double x) {
    return errcheck(sqrt(x), "sqrt");
}

double Pow(double x, double y) {
    return errcheck(pow(x, y), "exponentiation");
}

double integer(double x) {
    return (double) (long) x;
}
