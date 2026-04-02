BEGIN{in_print=0}
{
  line=$0
  if (in_print==1) {
    if (line ~ /^\s*\/\//) { print line } else { print "// " line }
    if (line ~ /\)\s*;/) { in_print=0 }
  } else {
    if (line ~ /print\(/) {
      if (line ~ /\)\s*;/) {
        if (line ~ /^\s*\/\//) { print line } else { print "// " line }
      } else {
        if (line ~ /^\s*\/\//) { print line } else { print "// " line }
        in_print=1
      }
    } else {
      print line
    }
  }
}
