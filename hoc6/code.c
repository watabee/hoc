#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hoc.h"
#include "y.tab.h"

extern FILE *fin;

char *emalloc(unsigned n);
extern double Pow(double x, double y);

#define NSTACK 256
static Datum stack[NSTACK]; // the stack
static Datum *stackp; // next free spot on stack

#define NPROG 2000
Inst prog[NPROG]; // the machine
Inst *progp; // next free spot for code generation
Inst *pc; // program counter during execution
Inst *progbase = prog; // start of current subprogram
int returning; // 1 if return stmt seen

// proc/func call stack frame
typedef struct Frame {
    Symbol *sp; // symbol table entry
    Inst *retpc; // where to resume after return
    Datum *argn; // n-th argument on stack
    int nargs; // number of arguments
} Frame;

#define NFRAME 100
Frame frame[NFRAME];
Frame *fp; // frame pointer

#define RESULT_BREAK     1
#define RESULT_CONTINUE  2

// initialize for code generation
void initcode() {
    progp = progbase;
    stackp = stack;
    fp = frame;
    returning = 0;
}

// install one instruction or operand
Inst *codeimpl(Inst f, const char *name) {
#if PRINT_MACHINE
    printf("%s\n", name);
#endif
    Inst *oprogp = progp;
    if (progp >= &prog[NPROG]) {
        execerror("program too big", (char *) 0);
    }
    *progp++ = f;
    return oprogp;
}

// push d onto stack
void push(Datum d) {
    if (stackp >= &stack[NSTACK]) {
        execerror("stack overflow", (char *) 0);
    }
    *stackp++ = d;
}

// pop and return top elem from stack
Datum pop() {
    if (stackp == stack) {
        execerror("stack underflow", (char *) 0);
    }
    return *--stackp;
}

// push constant onto stack
void constpush() {
    Datum d;
    d.val = ((Symbol *)*pc++)->u.val;
    push(d);
}

// push variable onto stack
void varpush() {
    Datum d;
    d.sym = (Symbol *)(*pc++);
    push(d);
}

void whilecode() {
    Datum d;
    Inst *savepc = pc; // loop body
    execute(savepc + 2); // condition
    d = pop();
    while (d.val) {
        execute(*((Inst **)(savepc))); // body
        if (returning) break;
        execute(savepc + 2); // condition
        d = pop();
    }
    if (!returning) {
        pc = *((Inst **)(savepc + 1)); // next statement
    }
}

void ifcode() {
    Datum d;
    Inst *savepc = pc; // then part

    execute(savepc + 3); // condition
    d = pop();
    if (d.val) {
        execute(*((Inst **)(savepc)));
    } else if (*((Inst **)(savepc + 1))) { // else part?
        execute(*((Inst **)(savepc + 1)));
    }
    if (!returning) {
        pc = *((Inst **)(savepc + 2)); // next stmt
    }
}

// put func/proc in symbol table
void define(Symbol *sp) {
    sp->u.defn = (Inst)progbase; // start of code
    progbase = progp; // next code starts here
}

// call a function
void call() {
    Symbol *sp = (Symbol *)pc[0]; // symbol table entry for function
    if (fp++ >= &frame[NFRAME - 1]) {
        execerror(sp->name, "call nested too deeply");
    }
    fp->sp = sp;
    fp->nargs = (int)pc[1];
    fp->retpc = pc + 2;
    fp->argn = stackp - 1; // last argument
    execute(sp->u.defn);
    returning = 0;
}

// common return from func or proc
void ret() {
    int i;
    for (i = 0; i < fp->nargs; i++) {
        pop(); // pop arguments
    }
    pc = (Inst *)fp->retpc;
    --fp;
    returning = 1;
}

// returning from a function
void funcret() {
    Datum d;
    if (fp->sp->type == PROCEDURE) {
        execerror(fp->sp->name, "(proc) returns value");
    }
    d = pop(); // preserve function return value
    ret();
    push(d);
}

// return from a procedure
void procret() {
    if (fp->sp->type == FUNCTION) {
        execerror(fp->sp->name, "(func) returns no value");
    }
    ret();
}

// return pointer to argument
double *getarg() {
    int nargs = (int) *pc++;
    if (nargs > fp->nargs) {
        execerror(fp->sp->name, "not enough arguments");
    }
    return &fp->argn[nargs - fp->nargs].val;
}

// push argument onto stack
void arg() {
    Datum d;
    d.val = *getarg();
    push(d);
}

// store top of stack in argument
void argassign() {
    Datum d;
    d = pop();
    push(d); // leave value on stack
    *getarg() = d.val;
}

// evaluate built-in on top of stack
void bltin() {
    Datum d;
    d = pop();
    d.val = (*(double (*)(double))(*pc++))(d.val);
    push(d);
}

// evaluate variable on stack
void eval() {
    Datum d;
    d = pop();
    if (d.sym->type != VAR && d.sym->type != UNDEF) {
        execerror("attempt to evaluate non-variable", d.sym->name);
    }
    if (d.sym->type == UNDEF) {
        execerror("undefined variable", d.sym->name);
    }
    d.val = d.sym->u.val;
    push(d);
}

// add top two elems on stack
void add() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val += d2.val;
    push(d1);
}

void sub() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val -= d2.val;
    push(d1);
}

void mul() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val *= d2.val;
    push(d1);
}

void div_() {
    Datum d1, d2;
    d2 = pop();
    if (d2.val == 0.0) {
        execerror("division by zero", (char *) 0);
    }
    d1 = pop();
    d1.val /= d2.val;
    push(d1);
}

void negate() {
    Datum d;
    d = pop();
    d.val = -d.val;
    push(d);
}

void gt() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val > d2.val);
    push(d1);
}

void lt() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val < d2.val);
    push(d1);
}

void ge() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val >= d2.val);
    push(d1);
}

void le() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val <= d2.val);
    push(d1);
}

void eq() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val == d2.val);
    push(d1);
}

void ne() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val != d2.val);
    push(d1);
}

void and() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val != 0.0 && d2.val != 0.0);
    push(d1);
}

void or() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = (double)(d1.val != 0.0 || d2.val != 0.0);
    push(d1);
}

void not() {
    Datum d;
    d = pop();
    d.val = (double)(d.val == 0.0);
    push(d);
}

void power() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = Pow(d1.val, d2.val);
    push(d1);
}

// assign top value to next value
void assign() {
    Datum d1, d2;
    d1 = pop();
    d2 = pop();
    if (d1.sym->type != VAR && d1.sym->type != UNDEF) {
        execerror("assignment to non-variable", d1.sym->name);
    }
    d1.sym->u.val = d2.val;
    d1.sym->type = VAR;
    push(d2);
}

// pop top value from stack, print it
void print() {
    Datum d;
    d = pop();
    printf("\t%.8g\n", d.val);
}

// print numeric value
void prexpr() {
    Datum d;
    d = pop();
    printf("\t%.8g\n", d.val);
}

// print string value
void prstr() {
    printf("%s", (char *)*pc++);
}

// read into variable
void varread() {
    Datum d;
    Symbol *var = (Symbol *)*pc++;
Again:
    switch (fscanf(fin, "%lf", &var->u.val)) {
        case EOF:
            if (moreinput()) {
                goto Again;
            }
            d.val = var->u.val = 0.0;
            break;
        case 0:
            execerror("non-number read into", var->name);
            break;
        default:
            d.val = 1.0;
            break;
    }
    var->type = VAR;
    push(d);
}

// run the machine
void execute(Inst *p) {
    for (pc = p; *pc != STOP && !returning;) {
		(*(*pc++))();
    }
}
