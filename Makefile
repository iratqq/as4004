SRCS=	parser.y lex.l
OBJS=	parser.o lex.o
PROG=	as4004
LEX=	 flex
LFLAGS= -i

LDADD=	 -ll

.SUFFIXES:
.SUFFIXES: .l .y .c .o

.l.c:
	${LEX} ${LFLAGS}
	mv lex.yy.c $@
.y.c:
	${YACC} $@
	mv y.tab.c $@

all: ${PROG}

${PROG}: ${OBJS}
	${CC} ${CFLAGS} -o $@ ${OBJS} ${LDADD}

clean:
	rm -f ${PROG} y.tab.h parser.c lex.c *.o

