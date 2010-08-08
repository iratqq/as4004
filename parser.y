%{
/*
 * Copyright (c) 2010 Iwata <iwata@quasiquote.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <stdio.h>
#include <stddef.h>
#include <ohash.h>
#include <sys/queue.h>

#define NO_JUMP -1

enum as_jump_range {
	AS_JUMP_NO = NO_JUMP,
	AS_JUMP_SHORT,
	AS_JUMP_LONG
};

struct rom_entry {
	int len;
	int bin;
	char *from_label;
	enum as_jump_range op_jump;
	char *to_label;

        TAILQ_ENTRY(rom_entry) rom_entries;
};
typedef TAILQ_HEAD(, rom_entry) rom_head;

static void *hash_alloc(size_t s, void *u);
static void hash_free(void *p, size_t s, void *u);
static void *element_alloc(size_t s, void *u);

struct label_list {
	int addr;
	char name[1];
};

static struct ohash_info label_info = {
	offsetof(struct label_list, name), NULL, hash_alloc, hash_free,
	element_alloc
};
struct ohash label_hash;

int lineno = 1;
rom_head rom;
extern FILE* yyin;

int yylex(void);
void yyerror(const char *);
int yyparse(void);
%}

%union {
	int op;
	int reg;
	int regpair;
	int data;
	char *from_label;
	char *to_label;
}

%type <op>       one_word_noarg_op one_word_reg_op
%type <op>       one_word_regpair_op one_word_data_op
%type <op>       two_word_addr_op two_word_cond_op
%type <op>       two_word_idxaddr_op two_word_idxdata_op

%type <reg>      reg_arg
%type <regpair>  regpair_arg
%type <data>     data_arg addr_arg
%type <to_label> label_arg

%token <from_label> ASLABEL_FROM
%token <to_label>   ASLABEL_TO

%token <data> AS_NUM

/* rom oprator */
%token <op> ASOP_NOP
/* %token <op> ASOP_JCN */
%token <op> ASOP_JNT ASOP_JC ASOP_JZ ASOP_JT ASOP_JNC ASOP_JNZ
%token <op> ASOP_FIM ASOP_SRC
%token <op> ASOP_FIN ASOP_JIN
%token <op> ASOP_JUN
%token <op> ASOP_JMS
%token <op> ASOP_INC
%token <op> ASOP_ISZ
%token <op> ASOP_ADD ASOP_SUB ASOP_LD ASOP_XCH ASOP_BBL ASOP_LDM

/* ram operator */
%token <op> ASOP_WRM ASOP_EMP ASOP_WRR ASOP_WPM
%token <op> ASOP_WR0 ASOP_WR1 ASOP_WR2 ASOP_WR3
%token <op> ASOP_SBM ASOP_RDM ASOP_RDR ASOP_ADM
%token <op> ASOP_RD0 ASOP_RD1 ASOP_RD2 ASOP_RD3

/* accumulator operators */
%token <op> ASOP_CLB ASOP_CLC ASOP_IAC ASOP_CMC
%token <op> ASOP_CMA ASOP_RAL ASOP_RAR ASOP_TCC
%token <op> ASOP_DAC ASOP_TCS ASOP_STC ASOP_DAA
%token <op> ASOP_KBP ASOP_DCL

/* regsters */
%token <reg> ASARG_REG0  ASARG_REG1  ASARG_REG2  ASARG_REG3
%token <reg> ASARG_REG4  ASARG_REG5  ASARG_REG6  ASARG_REG7
%token <reg> ASARG_REG8  ASARG_REG9  ASARG_REG10 ASARG_REG11
%token <reg> ASARG_REG12 ASARG_REG13 ASARG_REG14 ASARG_REG15

/* regster pairs */
%token <regpair> ASARG_REGPAIR0  ASARG_REGPAIR1  ASARG_REGPAIR2  ASARG_REGPAIR3
%token <regpair> ASARG_REGPAIR4  ASARG_REGPAIR5  ASARG_REGPAIR6  ASARG_REGPAIR7

%start statements

%%

statements:  /* empty */
          | statements statement
          ;

statement: label_line
         | operators
         ;

label_line: ASLABEL_FROM { as_insert_label($1); }
          ;

operators: one_word_op
         | two_word_op
         ;

one_word_op: one_word_noarg_op               { as_one_word_noarg($1);       }
           | one_word_reg_op reg_arg         { as_one_word_reg($1, $2);     }
           | one_word_regpair_op regpair_arg { as_one_word_regpair($1, $2); }
           | one_word_data_op data_arg      { as_one_word_data($1, $2);    }
           ;

two_word_op: two_word_addr_op addr_arg       { as_two_word_addr($1, $2);       }
           | two_word_addr_op label_arg      { as_two_word_label($1, $2);      }
           | two_word_cond_op addr_arg       { as_two_word_cond_addr($1, $2);  }
           | two_word_cond_op label_arg      { as_two_word_cond_label($1, $2); }
           | two_word_idxaddr_op reg_arg ',' addr_arg     { as_two_word_idxaddr_addr($1, $2, $4); }
           | two_word_idxaddr_op reg_arg ',' label_arg    { as_two_word_idxaddr_label($1, $2, $4); }
           | two_word_idxdata_op regpair_arg ',' data_arg { as_two_word_idx_data($1, $2, $4); }
           ;

one_word_noarg_op: ASOP_NOP { $$ = ASOP_NOP; }
                 | ASOP_WRM { $$ = ASOP_WRM; } | ASOP_EMP { $$ = ASOP_EMP; }
                 | ASOP_WRR { $$ = ASOP_WRR; } | ASOP_WPM { $$ = ASOP_WPM; }
                 | ASOP_WR0 { $$ = ASOP_WR0; } | ASOP_WR1 { $$ = ASOP_WR1; }
                 | ASOP_WR2 { $$ = ASOP_WR2; } | ASOP_WR3 { $$ = ASOP_WR3; }
                 | ASOP_SBM { $$ = ASOP_SBM; } | ASOP_RDM { $$ = ASOP_RDM; }
                 | ASOP_RDR { $$ = ASOP_RDR; } | ASOP_ADM { $$ = ASOP_ADM; }
                 | ASOP_RD0 { $$ = ASOP_RD0; } | ASOP_RD1 { $$ = ASOP_RD1; }
                 | ASOP_RD2 { $$ = ASOP_RD2; } | ASOP_RD3 { $$ = ASOP_RD3; }
                 | ASOP_CLB { $$ = ASOP_CLB; } | ASOP_CLC { $$ = ASOP_CLC; }
                 | ASOP_IAC { $$ = ASOP_IAC; } | ASOP_CMC { $$ = ASOP_CMC; }
                 | ASOP_CMA { $$ = ASOP_CMA; } | ASOP_RAL { $$ = ASOP_RAL; }
                 | ASOP_RAR { $$ = ASOP_RAR; } | ASOP_TCC { $$ = ASOP_TCC; }
                 | ASOP_DAC { $$ = ASOP_DAC; } | ASOP_TCS { $$ = ASOP_TCS; }
                 | ASOP_STC { $$ = ASOP_STC; } | ASOP_DAA { $$ = ASOP_DAA; }
                 | ASOP_KBP { $$ = ASOP_KBP; } | ASOP_DCL { $$ = ASOP_DCL; }
                 ;

one_word_reg_op: ASOP_INC { $$ = ASOP_INC; }
               | ASOP_ADD { $$ = ASOP_ADD; } |  ASOP_SUB { $$ = ASOP_SUB; }
               | ASOP_LD  { $$ = ASOP_LD;  } |  ASOP_XCH { $$ = ASOP_XCH; }
               ;

one_word_regpair_op: ASOP_FIN { $$ = ASOP_FIN; }
                   | ASOP_JIN { $$ = ASOP_JIN; }
                   ;

one_word_data_op: ASOP_BBL { $$ = ASOP_BBL; }
                | ASOP_LDM { $$ = ASOP_LDM; }
                ;

two_word_addr_op: ASOP_JUN { $$ = ASOP_JUN; }
                | ASOP_JMS { $$ = ASOP_JMS; }
                ;

two_word_cond_op: ASOP_JNT { $$ = ASOP_JNT; } | ASOP_JC  { $$ = ASOP_JC; }
                | ASOP_JZ  { $$ = ASOP_JZ;  } | ASOP_JT  { $$ = ASOP_JT; }
                | ASOP_JNC { $$ = ASOP_JNC; } | ASOP_JNZ { $$ = ASOP_JNZ; }
                ;

two_word_idxaddr_op: ASOP_ISZ { $$ = ASOP_ISZ; }
                   ;

two_word_idxdata_op: ASOP_FIM { $$ = ASOP_FIM; }
                   | ASOP_SRC { $$ = ASOP_SRC; }
                   ;

reg_arg: ASARG_REG0  { $$ = 0;  } |  ASARG_REG1  { $$ = 1;  }
       | ASARG_REG2  { $$ = 2;  } |  ASARG_REG3  { $$ = 3;  }
       | ASARG_REG4  { $$ = 4;  } |  ASARG_REG5  { $$ = 5;  }
       | ASARG_REG6  { $$ = 6;  } |  ASARG_REG7  { $$ = 7;  }
       | ASARG_REG8  { $$ = 8;  } |  ASARG_REG9  { $$ = 9;  }
       | ASARG_REG10 { $$ = 10; } |  ASARG_REG11 { $$ = 11; }
       | ASARG_REG12 { $$ = 12; } |  ASARG_REG13 { $$ = 13; }
       | ASARG_REG14 { $$ = 14; } |  ASARG_REG15 { $$ = 15; }
       ;

regpair_arg: ASARG_REGPAIR0  { $$ = 0; } |  ASARG_REGPAIR1  { $$ = 1; }
           | ASARG_REGPAIR2  { $$ = 2; } |  ASARG_REGPAIR3  { $$ = 3; }
           | ASARG_REGPAIR4  { $$ = 4; } |  ASARG_REGPAIR5  { $$ = 5; }
           | ASARG_REGPAIR6  { $$ = 6; } |  ASARG_REGPAIR7  { $$ = 7; }
           ;

data_arg: AS_NUM
        ;

addr_arg: AS_NUM
        ;

label_arg: ASLABEL_TO
         ;

%%



static void *
as_xmalloc(size_t size)
{
	void *ptr = malloc(size);
	if (ptr)
		return ptr;
	abort();
}

static void
init_rom_entry(struct rom_entry *entry)
{
	entry->len = 0;
	entry->bin = 0;
	entry->op_jump = NO_JUMP;
	entry->from_label = entry->to_label = NULL;
}

void as_insert_label(char *label)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->from_label = label;
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_one_word_noarg(int op)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 1;

	switch (op) {
	case ASOP_NOP:
		entry->bin = 0x00;
		break;

	case ASOP_WRM:
		entry->bin = 0xe0;
		break;
	case ASOP_EMP:
		entry->bin = 0xe1;
		break;
	case ASOP_WRR:
		entry->bin = 0xe2;
		break;
	case ASOP_WPM:
		entry->bin = 0xe3;
		break;
	case ASOP_WR0:
		entry->bin = 0xe4;
		break;
	case ASOP_WR1:
		entry->bin = 0xe5;
		break;
	case ASOP_WR2:
		entry->bin = 0xe6;
		break;
	case ASOP_WR3:
		entry->bin = 0xe7;
		break;
	case ASOP_SBM:
		entry->bin = 0xe8;
		break;
	case ASOP_RDM:
		entry->bin = 0xe9;
		break;
	case ASOP_RDR:
		entry->bin = 0xea;
		break;
	case ASOP_ADM:
		entry->bin = 0xeb;
		break;
	case ASOP_RD0:
		entry->bin = 0xec;
		break;
	case ASOP_RD1:
		entry->bin = 0xed;
		break;
	case ASOP_RD2:
		entry->bin = 0xee;
		break;
	case ASOP_RD3:
		entry->bin = 0xef;
		break;

	case ASOP_CLB:
		entry->bin = 0xf0;
		break;
	case ASOP_CLC:
		entry->bin = 0xf1;
		break;
	case ASOP_IAC:
		entry->bin = 0xf2;
		break;
	case ASOP_CMC:
		entry->bin = 0xf3;
		break;
	case ASOP_CMA:
		entry->bin = 0xf4;
		break;
	case ASOP_RAL:
		entry->bin = 0xf5;
		break;
	case ASOP_RAR:
		entry->bin = 0xf6;
		break;
	case ASOP_TCC:
		entry->bin = 0xf7;
		break;
	case ASOP_DAC:
		entry->bin = 0xf8;
		break;
	case ASOP_TCS:
		entry->bin = 0xf9;
		break;
	case ASOP_STC:
		entry->bin = 0xfa;
		break;
	case ASOP_DAA:
		entry->bin = 0xfb;
		break;
	case ASOP_KBP:
		entry->bin = 0xfc;
		break;
	case ASOP_DCL:
		entry->bin = 0xfd;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_one_word_reg(int op, int reg)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 1;

	switch (op) {
	case ASOP_INC:
		entry->bin = 0x60 | reg;
		break;
	case ASOP_ADD:
		entry->bin = 0x80 | reg;
		break;
	case ASOP_SUB:
		entry->bin = 0x90 | reg;
		break;
	case ASOP_LD:
		entry->bin = 0xa0 | reg;
		break;
	case ASOP_XCH:
		entry->bin = 0xb0 | reg;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_one_word_regpair(int op, int regpair)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 1;

	switch (op) {
	case ASOP_FIN:
		entry->bin = 0x30 | regpair << 9;
		break;
	case ASOP_JIN:
		entry->bin = 0x30 | regpair << 9 | 0x1 << 8;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_one_word_data(int op, int data)
{
	struct rom_entry *entry;

	if (0xf < data)
		yyerror("out of range");

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 1;

	switch (op) {
	case ASOP_BBL:
		entry->bin = 0xc0 | data;
		break;
	case ASOP_LDM:
		entry->bin = 0xd0 | data;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_two_word_addr(int op, int addr)
{
	struct rom_entry *entry;

	if (0xfff < addr)
		yyerror("out of range");

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_LONG;

	switch (op) {
	case ASOP_JUN:
		entry->bin = 0x4000 | addr;
		break;
	case ASOP_JMS:
		entry->bin = 0x5000 | addr;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void as_two_word_label(int op, char *label)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_LONG;

	switch (op) {
	case ASOP_JUN:
		entry->bin = 0x4000;
		entry->to_label = label;
		break;
	case ASOP_JMS:
		entry->bin = 0x5000;
		entry->to_label = label;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_two_word_cond_addr(int op, int addr)
{
	struct rom_entry *entry;

	if (0xff < addr)
		yyerror("out of range");

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_SHORT;

	switch (op) {
	/* case ASOP_JCN: */
	/* 	entry->bin = 0x1000 | addr; */
	/* 	break; */
	case ASOP_JNT:
		entry->bin = 0x1100 | addr;
		break;
	case ASOP_JC:
		entry->bin = 0x1200 | addr;
		break;
	case ASOP_JZ:
		entry->bin = 0x1400 | addr;
		break;
	case ASOP_JT:
		entry->bin = 0x1900 | addr;
		break;
	case ASOP_JNC:
		entry->bin = 0x1a00 | addr;
		break;
	case ASOP_JNZ:
		entry->bin = 0x1c00 | addr;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void as_two_word_cond_label(int op, char *label)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_SHORT;

	switch (op) {
	case ASOP_JNT:
		entry->bin = 0x1100;
		entry->to_label = label;
		break;
	case ASOP_JC:
		entry->bin = 0x1200;
		entry->to_label = label;
		break;
	case ASOP_JZ:
		entry->bin = 0x1400;
		entry->to_label = label;
		break;
	case ASOP_JT:
		entry->bin = 0x1900;
		entry->to_label = label;
		break;
	case ASOP_JNC:
		entry->bin = 0x1a00;
		entry->to_label = label;
		break;
	case ASOP_JNZ:
		entry->bin = 0x1c00;
		entry->to_label = label;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_two_word_idxaddr_addr(int op, int reg, int addr)
{
	struct rom_entry *entry;

	if (0xff < addr)
		yyerror("out of range");

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_SHORT;

	switch (op) {
	case ASOP_ISZ:
		entry->bin = 0x7000 | reg << 8 | addr;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_two_word_idxaddr_label(int op, int reg, char *label)
{
	struct rom_entry *entry;

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;
	entry->op_jump = AS_JUMP_SHORT;

	switch (op) {
	case ASOP_ISZ:
		entry->bin = 0x7000 | reg << 8;
		entry->to_label = label;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

void
as_two_word_idx_data(int op, int regpair, int data)
{
	struct rom_entry *entry;

	if (0xff < data)
		yyerror("out of range");

	entry = as_xmalloc(sizeof(struct rom_entry));
	init_rom_entry(entry);

	entry->len = 2;

	switch (op) {
	case ASOP_FIM:
		entry->bin = 0x2000 | regpair << 9 | data;
		break;
	case ASOP_SRC:
		entry->bin = 0x2000 | regpair << 9 | 0x1 << 8 | data;
		break;
	}
	TAILQ_INSERT_TAIL(&rom, entry, rom_entries);
}

/*
 * main
 */

static void *
hash_alloc(size_t s, void *u)
{
	void *p = as_xmalloc(s);
	if (p)
		memset(p, 0, s);
	return p;
}

static void
hash_free(void *p, size_t s, void *u)
{
        free(p);
}

static void *
element_alloc(size_t s, void *u)
{
        return as_xmalloc(s);
}

static struct label_list *
regist_label(const char *str)
{
	unsigned int i;
	struct label_list *l;
	const char *e = NULL;

	i = ohash_qlookupi(&label_hash, str, &e);
	l = ohash_find(&label_hash, i);
        if (l == NULL) {
                l = ohash_create_entry(&label_info, str, &e);
                ohash_insert(&label_hash, i, l);
	} else
		fprintf(stderr, "duplicate label `%s'\n", str);
	return l;
}

static struct label_list *
lookup_label(const char *str)
{
	return ohash_find(&label_hash, ohash_qlookup(&label_hash, str));
}

int
main(int argc, char *argv[])
{
	struct rom_entry *np;
	FILE *ofp;
	int count;
	struct label_list *ll;
	int i;

	if (argc != 3)
		return 1;

	if ((yyin = fopen(argv[1], "r")) == NULL) {
		perror("fopen");
		return 1;
	}

	if ((ofp = fopen(argv[2], "w")) == NULL) {
		perror("fopen");
		return 1;
	}

	ohash_init(&label_hash, 20, &label_info);
	TAILQ_INIT(&rom);

	yyparse();

	/* push jump address */
	count = 0;
	ll = NULL;
	TAILQ_FOREACH(np, &rom, rom_entries) {
		if (np->from_label) {
			ll = regist_label(np->from_label);
			ll->addr = count;
		}
		count += np->len;
	}

	count = 0;
	TAILQ_FOREACH(np, &rom, rom_entries) {
		int bin = np->bin;
		/* emit jump address */
		switch (np->op_jump) {
		case AS_JUMP_NO:
			break;
		case AS_JUMP_SHORT:
			ll = lookup_label(np->to_label);
			if (!ll) {
				fprintf(stderr, "label %s not found\n", np->to_label);
				break;
			}
			if ((count & 0xff00) == (ll->addr & 0xff00))
				bin |= ll->addr;
			else {
				fprintf(stderr, "cannot jump 0x%04x to 0x%04x\n", count, ll->addr);
			}
			break;
		case AS_JUMP_LONG:
			ll = lookup_label(np->to_label);
			if (!ll) {
				fprintf(stderr, "label %s not found\n", np->to_label);
				break;
			}
			bin |= ll->addr;
			break;
		}
		switch (np->len) {
		case 1:
			fputc(bin, ofp);
			break;
		case 2:
			fputc(bin >> 8, ofp);
			fputc(bin & 0xff, ofp);
			break;
		}
		count += np->len;
	}
	fclose(ofp);

	ohash_delete(&label_hash);

	while ((np = TAILQ_FIRST(&rom)) != NULL) {
		free(np->from_label);
		free(np->to_label);
		TAILQ_REMOVE(&rom, np, rom_entries);
		free(np);
	}

	return 0;
}
