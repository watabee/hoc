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

typedef union Datum { // interpreter stack type
    double val;
    Symbol *sym;
} Datum;
extern Datum pop();

typedef int (*Inst)();    // machine instruction
#define STOP    (Inst) 0

extern void init();
extern void initcode();
extern void execute(Inst *p);

extern void execerror(const char *s, const char *t);

extern Inst *code(Inst f);
extern Inst prog[];
extern void eval(), add(), sub(), mul(), div_(), negate(), power();
extern void assign(), bltin(), varpush(), constpush(), print();
