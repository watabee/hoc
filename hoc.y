%{
#include <stdio.h>
#include <stdlib.h>

#define YYSTYPE double  /* data type of yacc stack */

int yylex(void);
void yyerror(const char *s);
%}
%token  NUMBER
%left   '+' '-' /* left associattive, same precedence */
%left   '*' '/' /* left associattive, higher precedence */
%left   UNARYMINUS
%%
list:       /* nothing */
        | list '\n'
        | list expr '\n'  { printf("\t%.8g\n", $2); }
        ;
expr:       NUMBER      { $$ = $1; }
        | '-' expr %prec UNARYMINUS { $$ = -$2; }
        | expr '+' expr { $$ = $1 + $3; }
        | expr '-' expr { $$ = $1 - $3; }
        | expr '*' expr { $$ = $1 * $3; }
        | expr '/' expr { $$ = $1 / $3; }
        | '(' expr ')'  { $$ = $2; }
        ;
%%
        /* end of grammer */

#include <stdio.h>
#include <ctype.h>
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
        scanf("%lf", &yylval);
        return NUMBER;
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

int main(int argc, char **argv)
{
    progname = argv[0];
    yyparse();
}
