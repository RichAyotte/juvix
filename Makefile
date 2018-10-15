all: build

build:
	stack build --copy-bins --fast

build-js:
	stack build --compiler ghcjs-0.2.1.9011008_ghc-8.4.1 --fast

build-watch:
	stack build --copy-bins --fast --file-watch

build-opt: clean
	stack build --copy-bins --ghc-options "-O3 -DOPTIMIZE"

lint:
	stack exec -- hlint app codegen src test

test:
	stack test

repl-lib:
	stack ghci juvix:lib

repl-exe:
	stack ghci juvix:exe:juvix

repl-codegen:
	stack ghci juvix:exe:idris-codegen-juvix

clean:
	stack clean

clean-full:
	stack clean --full

.PHONY: all build build-js build-watch build-opt lint test repl-lib repl-exe repl-codegen clean clean-full
