#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "hoc.h"
#include "y.tab.h"

char *emalloc(unsigned n);
extern double Pow(double x, double y);

//int stack_size = 1;
int stack_size = 256;
static Datum *stack = NULL; // the stack
static Datum *stackp; // next free spot on stack

//int prog_size = 2;
int prog_size = 2000;
Inst *prog = NULL; // the machine
Inst *progp; // next free spot for code generation
Inst *pc; // program counter during execution

// initialize for code generation
void initcode() {
    if (stack == NULL) {
        stack = (Datum *) emalloc(sizeof(Datum) * stack_size);
    } else {
        memset(stack, 0, sizeof(Datum) * stack_size);
    }
    if (prog == NULL) {
        prog = (Inst *)emalloc(sizeof(Inst) * prog_size);
    } else {
        memset(prog, 0, sizeof(Inst) * prog_size);
    }

    stackp = stack;
    progp = prog;
}

// push d onto stack
void push(Datum d) {
    if (stackp >= stack + stack_size) {
        //printf("*** stack_size = %d\n", stack_size);
        Datum *newp = (Datum *)emalloc(sizeof(Datum) * stack_size * 2);
        memcpy((Datum *)newp, (Datum *)stack, sizeof(Datum) * stack_size);
        free(stack);
        stack = newp;
        stackp = stack + stack_size;
        stack_size = stack_size * 2;
    }
    *stackp++ = d;
}

// pop and return top elem from stack
Datum pop() {
    if (stackp <= stack) {
        execerror("stack underflow", (char *) 0);
    }
    return *--stackp;
}

// install one instruction or operand
Inst *code(Inst f) {
    Inst *oprogp = progp;
    if (progp >= prog + prog_size) {
        //printf("*** prog_size = %d\n", prog_size);
        Inst *newp = (Inst *)emalloc(sizeof(Inst) * prog_size * 2);
        memcpy((Inst *)newp, (Inst *)prog, sizeof(Inst) * prog_size);
        free(prog);
        prog = newp;
        progp = prog + prog_size;
        prog_size = prog_size * 2;
    }
    *progp++ = f;
    return oprogp;
}

// run the machine
void execute(Inst *p) {
    for (pc = p; *pc != STOP;) {
        (*(*pc++))();
    }
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

void power() {
    Datum d1, d2;
    d2 = pop();
    d1 = pop();
    d1.val = Pow(d1.val, d2.val);
    push(d1);
}

void negate() {
    Datum d;
    d = pop();
    d.val = -d.val;
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

// evaluate built-in on top of stack
void bltin() {
    Datum d;
    d = pop();
    d.val = (*(double (*)(double))(*pc++))(d.val);
    push(d);
}
