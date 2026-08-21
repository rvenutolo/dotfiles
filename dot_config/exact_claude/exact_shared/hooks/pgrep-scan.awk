# Mask quoted regions and emit tokens with byte offsets, in one linear pass.
# A command substitution re-enters an unquoted context even inside double
# quotes, because the shell expands it there -- that is what makes
# `until [ -z "$(pgrep --full x)" ]` visible to the scanner.
#
# An unquoted `#` that starts a word opens a comment, which the shell ignores to
# end of line. Masking it matters in both directions: a single apostrophe in
# prose ("it's", "don't") otherwise inverts quote parity for the whole rest of
# the command, which has been observed both exposing a quoted string as if it
# were code and hiding a real poll loop inside a quoted region.
BEGIN { RS = "\0"; ORS = "" }
{
  cmd = $0
  n = length(cmd)
  masked = ""
  depth = 0
  ctx[0] = "N"          # N unquoted, S single-quoted, D double-quoted
  i = 1
  while (i <= n) {
    ch = substr(cmd, i, 1)
    prev = (i > 1) ? substr(cmd, i - 1, 1) : ""
    cur = ctx[depth]
    out = ch
    if (cur == "S") {
      out = "\001"
      if (ch == "'") ctx[depth] = "N_END"
    } else if (cur == "D") {
      if (ch == "$" && substr(cmd, i + 1, 1) == "(") {
        masked = masked "$("; i += 2; depth++; ctx[depth] = "N"; opener[depth] = "P"; continue
      }
      if (ch == "`") {
        masked = masked "`"; i++
        if (depth > 0 && opener[depth] == "B") { depth-- } else { depth++; ctx[depth] = "N"; opener[depth] = "B" }
        continue
      }
      out = "\001"
      if (ch == "\\") { masked = masked "\001\001"; i += 2; continue }
      if (ch == "\"") ctx[depth] = "N_END"
    } else {
      # The whitespace-or-start precondition is load-bearing: without it the `#`
      # of `${#arr[@]}` would open a comment and mask the rest of the line.
      if (ch == "#" && (i == 1 || prev == " " || prev == "\t" || prev == "\n")) {
        while (i <= n && substr(cmd, i, 1) != "\n") { masked = masked "\001"; i++ }
        continue
      }
      if (ch == "$" && substr(cmd, i + 1, 1) == "(") {
        masked = masked "$("; i += 2; depth++; ctx[depth] = "N"; opener[depth] = "P"; continue
      }
      if (ch == ")" && depth > 0 && opener[depth] == "P") { masked = masked ")"; i++; depth--; continue }
      if (ch == "`") {
        masked = masked "`"; i++
        if (depth > 0 && opener[depth] == "B") { depth-- } else { depth++; ctx[depth] = "N"; opener[depth] = "B" }
        continue
      }

      if (ch == "'") { ctx[depth] = "S"; out = "\001" }
      else if (ch == "\"") { ctx[depth] = "D"; out = "\001" }
      else if (ch == "\\") { masked = masked "\001\001"; i += 2; continue }
    }
    if (ctx[depth] == "N_END") ctx[depth] = "N"
    masked = masked out
    i++
  }

  # Tokenize the masked string. Newline is emitted as the literal token <NL>
  # so it survives a line-oriented reader.
  word = ""; start = 0
  for (i = 1; i <= n; i++) {
    ch = substr(masked, i, 1)
    if (ch == " " || ch == "\t" || ch == "\n") {
      if (word != "") { print (start - 1) "\t" word "\n"; word = "" }
      if (ch == "\n") print (i - 1) "\t<NL>\n"
    } else if (index(";&|(){}`", ch) > 0) {
      if (word != "") { print (start - 1) "\t" word "\n"; word = "" }
      print (i - 1) "\t" ch "\n"
    } else {
      if (word == "") start = i
      word = word ch
    }
  }
  if (word != "") print (start - 1) "\t" word "\n"
}
