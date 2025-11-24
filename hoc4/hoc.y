%{
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "hoc.h"
#define code2(c1, c2)   code(c1); code(c2)
#define code3(c1, c2, c3)   code(c1); code(c2); code(c3)
int yylex(void);
void yyerror(const char *s);
%}
%union {
        Symbol  *sym;  /* symbol table pointer */
        Inst    *inst; /* machine instruction */
}
%token  <sym>   NUMBER VAR BLTIN UNDEF
%right  '='
%left   '+' '-' /* left associattive, same precedence */
%left   '*' '/' '%' /* left associattive, higher precedence */
%left   UNARYMINUS
%right  '^'     /* exponentiation */
%%
list:       /* nothing */
        | list '\n'
        | list asgn '\n'  { code2((Inst)pop, STOP); return 1; }
        | list expr '\n'  { code2((Inst)print, STOP); return 1; }
        | list error '\n' { yyerrok; }
        ;
asgn:     VAR '=' expr { code3((Inst)varpush, (Inst)$1, (Inst)assign); }
        ;
expr:     NUMBER { code2((Inst)constpush, (Inst)$1); }
        | VAR { code3((Inst)varpush, (Inst)$1, (Inst)eval); }
        | asgn
        | BLTIN '(' expr ')'    { code2((Inst)bltin, (Inst)$1->u.ptr); }
        | '(' expr ')'
        | expr '+' expr { code((Inst)add); }
        | expr '-' expr { code((Inst)sub); }
        | expr '*' expr { code((Inst)mul); }
        | expr '/' expr { code((Inst)div_); }
        | expr '^' expr { code((Inst)power); }
        | '-' expr %prec UNARYMINUS  { code((Inst)negate); }
        ;
%%
        /* end of grammer */

#include <stdio.h>
#include <ctype.h>
#include <signal.h>
#include <setjmp.h>
jmp_buf begin;
char    *progname;  /* for error messages */
int     lineno = 1;

int yylex(void)
{
    int c;
    while ((c = getchar()) == ' ' || c == '\t');

    if (c == EOF) {
        return 0;
    }
    if (c == '.' || isdigit(c)) { /* number */
        double d;
        ungetc(c, stdin);
        scanf("%lf", &d);
        yylval.sym = install("", NUMBER, d);
        return NUMBER;
    }
    if (isalpha(c)) {
        Symbol *s;
        char sbuf[100], *p = sbuf;
        do {
            *p++ = c;
        } while ((c = getchar()) != EOF && isalnum(c));
        ungetc(c, stdin);
        *p = '\0';
        if ((s = lookup(sbuf)) == 0) {
            s = install(sbuf, UNDEF, 0.0);
        }
        yylval.sym = s;
        return s->type == UNDEF ? VAR : s->type;
    }
    if (c == '\n') {
        lineno++;
    }
    return c;
}

static void warning(const char *s, const char *t)   /* print warning message */
{
    fprintf(stderr, "%s: %s", progname, s);
    if (t) {
        fprintf(stderr, " %s", t);
    }
    fprintf(stderr, " near line %d\n", lineno);
}

void yyerror(const char *s)      /* called for yacc syntax error */
{
    warning(s, (char *) 0);
}

void execerror(const char *s, const char *t) {  /* recover from run-time error */
    warning(s, t);
    longjmp(begin, 0);
}

void fpecatch(int signum) {    /* catch floating point exceptions */
    execerror("floating point exception", (const char *) 0);
}

int main(int argc, char **argv)
{
    progname = argv[0];
    init();
    setjmp(begin);
    signal(SIGFPE, fpecatch);
    for (initcode(); yyparse(); initcode()) {
        execute(prog);
    }
    return 0;
}
