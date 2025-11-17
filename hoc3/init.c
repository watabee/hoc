#include "hoc.h"
#include "y.tab.h"
#include <stdlib.h>
#include <math.h>

extern double Rand(), Atan2(), Log(), Log10(), Exp(), Sqrt(), integer();
// Constants
static struct {
    char *name;
    double cval;
} consts[] = {
    "PI",    3.14159265358979323846,
    "E",     2.71828182845904523536,
    "GAMMA", 0.57721566490153286060, // Euler
    "DEG",   57.29577951308232087680, // deg/radian
    "PHI",   1.61803398874989484820, // golden ratio
    0,       0
};

// Built-ins
static struct {
    char *name;
    double (*func)();
} builtins[] = {
    "sin",   sin,
    "cos",   cos,
    "atan",  atan,
    "log",   Log, // checks argument
    "log10", Log10, // checks argument
    "exp",   Exp, // checks argument
    "sqrt",  Sqrt, // checks argument
    "int",   integer, // checks argument
    "abs",   fabs, // checks argument
    0,       0
};

static struct {
    char *name;
    double (*func)();
} builtins0[] = {
    "rand", Rand,
    0,       0
};

static struct {
    char *name;
    double (*func)();
} builtins2[] = {
    "atan2", Atan2,
    0,       0
};

// install constants and built-ins in table
void init() {
    int i;
    Symbol *s;

    for (i = 0; consts[i].name; i++) {
        install(consts[i].name, VAR, consts[i].cval, 1);
    }
    for (i = 0; builtins0[i].name; i++) {
        s = install(builtins0[i].name, BLTIN, 0.0, 1);
        s->u.ptr0 = builtins0[i].func;
    }
    for (i = 0; builtins[i].name; i++) {
        s = install(builtins[i].name, BLTIN, 0.0, 1);
        s->u.ptr = builtins[i].func;
    }
    for (i = 0; builtins2[i].name; i++) {
        s = install(builtins2[i].name, BLTIN, 0.0, 1);
        s->u.ptr2 = builtins2[i].func;
    }
}
