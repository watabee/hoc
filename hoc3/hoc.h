typedef struct Symbol { // symbol table entry
    char *name;
    short type; // VAR, BLTIN, UNDEF
    char constant;
    union {
        double val; // if VAR
        double (*ptr0)(); // if BLTIN
        double (*ptr)(double); // if BLTIN
        double (*ptr2)(double, double); // if BLTIN
    } u;
    struct Symbol *next; // to link to another
} Symbol;
Symbol *install(char *s, int t, double d, char constant), *lookup(char *s);
