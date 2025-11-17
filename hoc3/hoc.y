%{
#include <stdio.h>
#include <math.h>
#include "hoc.h"
extern void init();
extern double Pow(double x, double y);
void execerror(const char *s, const char *t);
int yylex(void);
void yyerror(const char *s);
%}
%union {
        double  val;   /* actual type */
        Symbol  *sym;  /* symbol table pointer */
}
%token  <val>   NUMBER
%token  <sym>   VAR BLTIN UNDEF
%type   <val>   expr asgn
%right  '='
%left   '+' '-' /* left associattive, same precedence */
%left   '*' '/' '%' /* left associattive, higher precedence */
%left   UNARY
%right  '^'     /* exponentiation */
%%
list:       /* nothing */
        | list '\n'
        | list asgn '\n'
        | list expr '\n'  { printf("\t%.8g\n", $2); }
        | list error '\n' { yyerrok; }
        ;
asgn:     VAR '=' expr {
                if ($1->constant)
                    execerror("cannot assign to $s\n", $1->name);
                $$=$1->u.val=$3; $1->type = VAR; }
        ;
expr:     NUMBER
        | VAR { if ($1->type == UNDEF)
                    execerror("undefined variable", $1->name);
                $$ = $1->u.val; }
        | asgn
        | BLTIN '(' ')'    { $$ = (*($1->u.ptr0))(); }
        | BLTIN '(' expr ')'    { $$ = (*($1->u.ptr))($3); }
        | BLTIN '(' expr ',' expr ')'    { $$ = (*($1->u.ptr2))($3, $5); }
        | expr '+' expr { $$ = $1 + $3; }
        | expr '-' expr { $$ = $1 - $3; }
        | expr '*' expr { $$ = $1 * $3; }
        | expr '/' expr {
                if ($3 == 0.0)
                    execerror("division by zero", "");
                $$ = $1 / $3; }
        | expr '%' expr { $$ = fmod($1, $3); }
        | expr '^' expr { $$ = Pow($1, $3); }
        | '(' expr ')'  { $$ = $2; }
        | '+' expr %prec UNARY  { $$ = +$2; }
        | '-' expr %prec UNARY  { $$ = -$2; }
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
        ungetc(c, stdin);
        scanf("%lf", &yylval.val);
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
            s = install(sbuf, UNDEF, 0.0, 0);
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
    yyparse();
}
