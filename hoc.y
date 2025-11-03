%{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define PREV_MEM_IDX 15 /* The index of mem[] used to store calculation results */

double  mem[26]; /* memory for variables 'a'..'z' */

void execerror(const char *s, const char *t);
int yylex(void);
void yyerror(const char *s);
%}
%union {                /* stack type */
        double  val;    /* actual type */
        int     index;  /* index into mem[] */
}
%token  <val>   NUMBER
%token  <index> VAR
%type   <val>   expr
%right  '='
%left   '+' '-' /* left associattive, same precedence */
%left   '*' '/' '%' /* left associattive, higher precedence */
%left   UNARY
%%
list:       /* nothing */
        | list '\n'
        | list expr '\n'  { printf("\t%.8g\n", $2); }
        | list expr ';'  { printf("\t%.8g\n", $2); }
        | list error '\n' { yyerrok; }
        ;
expr:     NUMBER        { $$ = $1; }
        | VAR           { $$ = mem[$1]; }
        | VAR '=' expr  { $$ = mem[$1] = $3; }
        | expr '+' expr { $$ = mem[PREV_MEM_IDX] = $1 + $3; }
        | expr '-' expr { $$ = mem[PREV_MEM_IDX] = $1 - $3; }
        | expr '*' expr { $$ = mem[PREV_MEM_IDX] = $1 * $3; }
        | expr '/' expr {
                if ($3 == 0.0)
                    execerror("division by zero", "");
                $$ = mem[PREV_MEM_IDX] = $1 / $3; }
        | expr '%' expr { $$ = mem[PREV_MEM_IDX] = fmod($1, $3); }
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
    if (islower(c)) {
        yylval.index = c - 'a'; /* ASCII only */
        return VAR;
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
    setjmp(begin);
    signal(SIGFPE, fpecatch);
    yyparse();
}
