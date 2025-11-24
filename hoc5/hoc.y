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
%token  <sym>   NUMBER PRINT VAR BLTIN UNDEF WHILE IF ELSE
%type   <inst>  stmt asgn expr stmtlist cond while if end
%right  '='
%left   OR
%left   AND
%left   GT GE LT LE EQ NE
%left   '+' '-' /* left associattive, same precedence */
%left   '*' '/' '%' /* left associattive, higher precedence */
%left   UNARYMINUS NOT
%right  '^'     /* exponentiation */
%%
list:       /* nothing */
        | list '\n'
        | list asgn '\n'  { code2((Inst)pop, STOP); return 1; }
        | list stmt '\n'  { code(STOP); return 1; }
        | list expr '\n'  { code2((Inst)print, STOP); return 1; }
        | list error '\n' { yyerrok; }
        ;
asgn:     VAR '=' expr { code3((Inst)varpush, (Inst)$1, (Inst)assign); }
        ;
stmt:     expr { code((Inst)pop); }
        | PRINT expr { code((Inst)prexpr); $$ = $2; }
        | while cond stmt end {
                ($1)[1] = (Inst)$3;     /* body of loop */
                ($1)[2] = (Inst)$4; }   /* end, if cond fails */
        | if cond stmt end { /* else-less if */
                ($1)[1] = (Inst)$3;     /* then part */
                ($1)[3] = (Inst)$4; }   /* end, if cond fails */
        | if cond stmt end ELSE stmt end { /* if with else */
                ($1)[1] = (Inst)$3;     /* then part */
                ($1)[2] = (Inst)$6;     /* else part */
                ($1)[3] = (Inst)$7; }   /* end, if cond fails */
        | '{' stmtlist '}' { $$ = $2; }
        ;
cond:    '(' expr ')' { code(STOP); $$ = $2; }
        ;
while:   WHILE { $$ = code3((Inst)whilecode, STOP, STOP); }
        ;
if:      IF { $$ = code((Inst)ifcode); code3(STOP, STOP, STOP); }
        ;
end:     /* nothing */  { code(STOP); $$ = progp; }
        ;
stmtlist: /* nothing */  { $$ = progp; }
        | stmtlist '\n'
        | stmtlist stmt
        ;
expr:     NUMBER { $$ = code2((Inst)constpush, (Inst)$1); }
        | VAR { $$ = code3((Inst)varpush, (Inst)$1, (Inst)eval); }
        | asgn
        | BLTIN '(' expr ')'    { $$ = $3; code2((Inst)bltin, (Inst)$1->u.ptr); }
        | '(' expr ')' { $$ = $2; }
        | expr '+' expr { code((Inst)add); }
        | expr '-' expr { code((Inst)sub); }
        | expr '*' expr { code((Inst)mul); }
        | expr '/' expr { code((Inst)div_); }
        | expr '^' expr { code((Inst)power); }
        | '-' expr %prec UNARYMINUS  { $$ = $2; code((Inst)negate); }
        | expr GT expr { code((Inst)gt); }
        | expr GE expr { code((Inst)ge); }
        | expr LT expr { code((Inst)lt); }
        | expr LE expr { code((Inst)le); }
        | expr EQ expr { code((Inst)eq); }
        | expr NE expr { code((Inst)ne); }
        | expr AND expr { code((Inst)and); }
        | expr OR expr { code((Inst)or); }
        | NOT expr { $$ = $2; code((Inst)not); }
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

// look after for >=, etc.
int follow(int expect, int ifyes, int ifno) {
    int c = getchar();
    if (c == expect)
        return ifyes;
    ungetc(c, stdin);
    return ifno;
}

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
    switch (c) {
        case '>':   return follow('=', GE, GT);
        case '<':   return follow('=', LE, LT);
        case '=':   return follow('=', EQ, '=');
        case '!':   return follow('=', NE, NOT);
        case '|':   return follow('|', OR, '|');
        case '&':   return follow('&', AND, '&');
        case '\n':  lineno++;   return '\n';
        default:    return c;
    }
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
