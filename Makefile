clean:
	nvim --headless --clean -n -c "lua vim.fn.delete('./tests/.deps', 'rf')" +q
test:
	nvim --headless --clean -u tests/test.lua "$(FILE)"
# Re-run CI tests 3 times before failing, to avoid reporting false negatives
test-ci:
	for i in {1..3}; do nvim --headless --clean -u tests/test.lua && s=0 && break || s=$$? && sleep 1; done; exit $$s
vim_docs:
	./scripts/build_docs.sh
api_docs:
	nvim --headless --clean -u ./scripts/gendoc.lua
setup_dev:
	cp ./scripts/pre-commit-hook.sh ./.git/hooks/pre-commit && chmod +x ./.git/hooks/pre-commit
lint:
	stylua --check lua/ tests/
format:
	stylua lua/ tests/
