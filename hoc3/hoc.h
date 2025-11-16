typedef struct Symbol { // symbol table entry
    char *name;
    short type; // VAR, BLTIN, UNDEF
    union {
        double val; // if VAR
        double (*ptr)(double); // if BLTIN
    } u;
    struct Symbol *next; // to link to another
} Symbol;
Symbol *install(char *s, int t, double d), *lookup(char *s);
