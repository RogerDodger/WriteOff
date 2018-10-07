# Makefile for WriteOff.pm

C_COMP = gcc
EF_DST = bin/libsqlitefunctions.so
EF_SRC = lib/extension-functions.c

BCS_DST = bin/libsqlitebcsum.so
BCS_SRC = lib/bcsum.c

css_dir   = root/static/style
sass_src  = $(css_dir)/scss/writeoff.scss
sass_dest = $(css_dir)/writeoff.css

js_url = /static/js
js_dir = root$(js_url)

js_cat  = awk 'BEGINFILE { printf "/* %s */;\n", FILENAME } { print } ENDFILE { print "" }'
css_cat = awk 'BEGINFILE { printf "/* %s */\n", FILENAME } { print } ENDFILE { print "" }'

all: bcs ef css js

clean:
	rm $(EF_DST) $(BCS_DST)

bcs:
	$(C_COMP) -fPIC -shared $(BCS_SRC) -o $(BCS_DST) -lm

ef:
	$(C_COMP) -fPIC -shared $(EF_SRC) -o $(EF_DST) -lm


css:
	sassc $(sass_src) $(sass_dest)
	postcss --use autoprefixer -o $(sass_dest) $(sass_dest)
	$(css_cat) $(css_dir)/vendor/*.css > $(css_dir)/vendor.css

js: js-cat js-min

js-cat:
	$(js_cat) $(js_dir)/vendor/*.js > $(js_dir)/vendor.js

js-min:
	terser -c -m -o $(js_dir)/writeoff.min.js $(js_dir)/writeoff.js
