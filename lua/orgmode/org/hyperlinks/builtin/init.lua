local Http = require('orgmode.org.hyperlinks.builtin.http')
local Https = require('orgmode.org.hyperlinks.builtin.https')
local File = require('orgmode.org.hyperlinks.builtin.file')
local Id = require('orgmode.org.hyperlinks.builtin.id')
local Internal = require('orgmode.org.hyperlinks.builtin.internal')

return {
  Internal,
  [Http.protocol] = Http,
  [Https.protocol] = Https,
  [File.protocol] = File,
  [Id.protocol] = Id,
}
