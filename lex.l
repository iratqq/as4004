%{ /* -*- C -*- */
/*
 * Copyright (c) 2010- Iwata <iwata@quasiquote.org>
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
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include "y.tab.h"

extern int lineno;

void yyerror(const char *);
%}
%%

 /* rom oprator */
NOP { return ASOP_NOP; }
 /* JCN { return ASOP_JCN; } */
JNT { return ASOP_JNT; }
JC  { return ASOP_JC;  }
JZ  { return ASOP_JZ;  }
JT  { return ASOP_JT;  }
JNC { return ASOP_JNC; }
JNZ { return ASOP_JNZ; }
FIM { return ASOP_FIM; }
SRC { return ASOP_SRC; }
FIN { return ASOP_FIN; }
JIN { return ASOP_JIN; }
JUN { return ASOP_JUN; }
JMS { return ASOP_JMS; }
INC { return ASOP_INC; }
ISZ { return ASOP_ISZ; }
ADD { return ASOP_ADD; }
SUB { return ASOP_SUB; }
LD  { return ASOP_LD;  }
XCH { return ASOP_XCH; }
BBL { return ASOP_BBL; }
LDM { return ASOP_LDM; }

 /* ram operator */
WRM { return ASOP_WRM; }
EMP { return ASOP_EMP; }
WRR { return ASOP_WRR; }
WPM { return ASOP_WPM; }
WR0 { return ASOP_WR0; }
WR1 { return ASOP_WR1; }
WR2 { return ASOP_WR2; }
WR3 { return ASOP_WR3; }
SBM { return ASOP_SBM; }
RDM { return ASOP_RDM; }
RDR { return ASOP_RDR; }
ADM { return ASOP_ADM; }
RD0 { return ASOP_RD0; }
RD1 { return ASOP_RD1; }
RD2 { return ASOP_RD2; }
RD3 { return ASOP_RD3; }

 /* accumulator operators */
CLB { return ASOP_CLB; }
CLC { return ASOP_CLC; }
IAC { return ASOP_IAC; }
CMC { return ASOP_CMC; }
CMA { return ASOP_CMA; }
RAL { return ASOP_RAL; }
RAR { return ASOP_RAR; }
TCC { return ASOP_TCC; }
DAC { return ASOP_DAC; }
TCS { return ASOP_TCS; }
STC { return ASOP_STC; }
DAA { return ASOP_DAA; }
KBP { return ASOP_KBP; }
DCL { return ASOP_DCL; }

 /* regster pairs */
R0R1   { return ASARG_REGPAIR0; }
R2R3   { return ASARG_REGPAIR1; }
R4R5   { return ASARG_REGPAIR2; }
R6R7   { return ASARG_REGPAIR3; }
R8R9   { return ASARG_REGPAIR4; }
R10R11 { return ASARG_REGPAIR5; }
R12R13 { return ASARG_REGPAIR6; }
R14R15 { return ASARG_REGPAIR7; }

 /* regsters */
R0  { return ASARG_REG0;  }
R1  { return ASARG_REG1;  }
R2  { return ASARG_REG2;  }
R3  { return ASARG_REG3;  }
R4  { return ASARG_REG4;  }
R5  { return ASARG_REG5;  }
R6  { return ASARG_REG6;  }
R7  { return ASARG_REG7;  }
R8  { return ASARG_REG8;  }
R9  { return ASARG_REG9;  }
R10 { return ASARG_REG10; }
R11 { return ASARG_REG11; }
R12 { return ASARG_REG12; }
R13 { return ASARG_REG13; }
R14 { return ASARG_REG14; }
R15 { return ASARG_REG15; }

^[_A-Z][_A-Z0-9]*: {
	size_t len = strlen(yytext);

	yylval.from_label = strdup(yytext);
	yylval.from_label[len - 1] = '\0';
	return ASLABEL_FROM;
 }

[_A-Z][_A-Z0-9]* { yylval.to_label = strdup(yytext); return ASLABEL_TO; }

[0-9]+   {
	char *ep;
	long lval;

	errno = 0;
	lval = strtol(yytext, &ep, 10);
	if (*ep != '\0')
		yyerror("not a number");
	if ((errno == ERANGE && (lval == LONG_MAX || lval == LONG_MIN)) ||
	     (lval > INT_MAX || lval < INT_MIN))
		yyerror("out of range");
	yylval.data = lval;

	return AS_NUM;
}
0x[0-9A-F]+ {
	char *ep;
	long lval;

	errno = 0;
	lval = strtol(&yytext[2], &ep, 16);
	if (*ep != '\0')
		yyerror("not a number");
	if ((errno == ERANGE && (lval == LONG_MAX || lval == LONG_MIN)) ||
	     (lval > INT_MAX || lval < INT_MIN))
		yyerror("out of range");
	yylval.data = lval;
	return AS_NUM;
}

;.*      ;
[\t ]+   ;
\n       { lineno++; }
.        { return yytext[0]; }
%%

void
yyerror(const char *s)
{
	fprintf(stderr, "%d: %s at %s\n", lineno, s, yytext);
}
