.PHONY: test fmt link deps documentation

default: all

all: fmt lint test documentation

fmt:
	stylua lua/ --config-path=.stylua.toml

lint:
	luacheck lua/ --globals vim

test:
	nvim --headless --noplugin -u scripts/test/minimal.vim \
		-c "PlenaryBustedDirectory lua/marlin/test/ {minimal_init = 'scripts/test/minimal.vim'}"

deps:
	@mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.nvim deps/mini.nvim

documentation:
	nvim --headless --noplugin -u ./scripts/minimal_init_doc.lua -c "lua require('mini.doc').generate()" -c "qa!"

documentation-ci: deps documentation
