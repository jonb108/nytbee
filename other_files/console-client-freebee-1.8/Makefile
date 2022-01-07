# freebee Makefile

CC ?=		cc
CFLAGS ?=	-O2 -pipe
CFLAGS +=	-I/usr/local/include

# Remove if your system doesn't have
# arc4random_uniform(3) and/or strlcat(3)
# Same with pledge(2) and/or unveil(2)
#CFLAGS +=	-DHAVE_ARC4RANDOM_UNIFORM -DHAVE_STRLCAT
#CFLAGS +=	-DHAVE_PLEDGE -DHAVE_UNVEIL

# Uncomment if you don't want to install
# or if you plan to install the dictionary somewhere
# other than /usr/local/share/freebee/enable1.txt
#CFLAGS +=	-DDICTIONARY="\"enable1.txt\""

PREFIX ?=	/usr/local
BINDIR ?=	${PREFIX}/bin
MANDIR ?=	${PREFIX}/man/man6
SHAREDIR ?=	${PREFIX}/share/freebee

PROG =	freebee
OBJS =	anagram.o arc4random_uniform.o dir.o game.o main.o net.o rank.o \
	strlcat.o

all: ${OBJS}
	${CC} ${LDFLAGS} -o ${PROG} ${OBJS} -lncurses -L/usr/local/lib -lcurl

install:
	/usr/bin/install -d -m 755 ${BINDIR}
	/usr/bin/install -d -m 755 ${MANDIR}
	/usr/bin/install -d -m 755 ${SHAREDIR}
	/usr/bin/install -c -s -m 555 freebee ${BINDIR}
	/usr/bin/install -c -m 444 freebee.6 ${MANDIR}
	/usr/bin/install -c -m 444 enable1.txt ${SHAREDIR}

clean:
	rm -f ${PROG} ${OBJS} ${PROG}.core
