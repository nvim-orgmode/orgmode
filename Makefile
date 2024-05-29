clean:
	nvim --headless --clean -n -c "lua vim.fn.delete('./tests/.deps', 'rf')" +q
test:
	nvim --headless --clean -u tests/test.lua "$(FILE)"
api_docs:
	nvim --headless --clean -u ./scripts/gendoc.lua
setup_dev:
	cp ./scripts/pre-commit-hook.sh ./.git/hooks/pre-commit && chmod +x ./.git/hooks/pre-commit
lint:
	stylua --check lua/ tests/
format:
	stylua lua/ tests/
