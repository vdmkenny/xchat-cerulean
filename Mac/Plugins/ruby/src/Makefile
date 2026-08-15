RUBY=ruby
CC=gcc
CFLAGS=-g -Wall -O1 -fPIC

OBJ=xchat-ruby.o

ARCHDIR=`$(RUBY) -rrbconfig -e "puts Config::CONFIG['archdir']"`

XCHAT_RUBY=xchat-ruby
SO_FILE=$(XCHAT_RUBY).so
XCHAT_DIR=~/.xchat2

.SUFFIXES: .c .o .rb .h

.rb.h:
	$(RUBY) ../scripts/embedify.rb $*.rb $*.h

.c.o:
	$(CC) $(CFLAGS) -c -I$(ARCHDIR) $*.c -o $*.o

all: $(SO_FILE)

$(SO_FILE): xchat-ruby.o xchat-ruby-plugin.h
	$(CC) -L$(ARCHDIR) $(CFLAGS) -shared -o $(SO_FILE) xchat-ruby.o -lruby

install: $(SO_FILE)
	mkdir -p $(XCHAT_DIR)
	cp $(SO_FILE) $(XCHAT_DIR)
	$(RUBY) -e 'puts $$LOAD_PATH.join("\n")' > $(XCHAT_DIR)/rubyenv

uninstall:
	rm $(XCHAT_DIR)/$(SO_FILE) $(XCHAT_DIR)/rubyenv

clean:
	rm -f $(SO_FILE) $(OBJ) xchat-ruby-plugin.h

xchat-ruby.o: xchat-ruby-plugin.h
