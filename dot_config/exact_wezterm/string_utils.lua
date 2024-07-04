local module = {}

function module.is_empty(s)
  return s == nil or s == ""
end

function module.basename(path)
  return string.gsub(path, "(.*[/\\])(.*)", "%2")
end

function module.remove_trailing_slash(s)
  return string.gsub(s, "/$", "")
end

return module
