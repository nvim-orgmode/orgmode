local function register()
  require('orgmode.org.autocompletion.compe')
  require('orgmode.org.autocompletion.cmp')
end

return {
  register = register,
}
