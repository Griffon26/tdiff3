CPPFLAGS = -Istub -Isrc
CFLAGS = -Wall -ggdb

SRCS = src/analyze.c \
			 src/util.c \
			 stub/diff.c \
			 stub/normal.c \
			 stub/zalloc.c

OBJS = $(patsubst %.c,%.o,$(SRCS))

libgnudiff.a: $(OBJS) Makefile
	\rm -f $@
	ar rcs $@ $(OBJS)

.PHONY: clean
clean:
	rm -f $(OBJS) libgnudiff.a

