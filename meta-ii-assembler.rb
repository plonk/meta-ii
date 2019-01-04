def next_tok!(str)
  case str
  when /^\d+\.\d+/
    str.replace($')
    $&.to_f
  when /^\d+/
    str.replace($')
    $&.to_i
  when /^\s+/
    str.replace($')
    next_tok!(str)
  when ""
    nil
  when /^"[^"]*"/
    str.replace($')
    eval($&)
  when /^'[^']*'/
    str.replace($')
    eval($&)
  when /^[A-Za-z][A-Za-z0-9]*/
    str.replace($')
    $&.to_sym
  else
    p str
    fail
  end
end

def resolve_labels(prog, labels)
  unless prog[0][0] == :adr
    fail "first inst is not adr"
  end

  entry_point = prog[0][1]
  unless labels[entry_point]
    fail "entry point #{entry_point} not found"
  end
  prog[0] = labels[entry_point]

  prog.map { |data|
    if data.is_a? Array
      [data[0], *data[1..-1].map { |tok| if tok.is_a?(Symbol) then labels[tok] else tok end }]
    else
      data
    end
  }
end

prog = []
labels = {}

ARGF.each_line do |line|
  line.chomp!
  if line !~ /^\s/
    labels[line.strip.to_sym] = prog.size
  else
    op = next_tok!(line)

    if op == :end
      break
    else
      rest = []
      while tok = next_tok!(line)
        rest << tok
      end
      prog << [op, *rest]
    end
  end
end

prog = resolve_labels(prog, labels)

require 'pp'
# pp labels
pp prog
