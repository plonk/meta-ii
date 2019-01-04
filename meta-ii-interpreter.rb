require 'pp'
def next_token(str)
  case str
  when /\A\*[12]?/
    return $&.to_sym, $'
  when /\A\.?[A-Za-z][A-Za-z0-9]*/
    return $&.to_sym, $'
  when /\A\d+/
    return $&.to_i, $'
  when /\A\d+\.\d+/
    return $&.to_f, $'
  when /\A"[^"]*"/
    return $&[1..-2], $'
  when /\A'[^']*'/
    return $&[1..-2], $'
  when /\A[;\/$=()*]/
    return $&.to_sym, $'
  when /\A\s+/
    return next_token($')
  when ""
    return nil
  else
    fail "invalid token at #{str[0..10].inspect} ..."
  end
end

def tokenize(str)
  tokens = []
  while true
    r = next_token(str)
    break if r.nil?
    v, str = r
    tokens << v
  end
  return tokens
end

class MatchFailed < StandardError
end

module Parsing
  module_function

  # tokens -> (AST, tokens)

  def syntax(tokens)
    tokens = expect(:".syntax", tokens)
    if id?(tokens[0])
      name = tokens[0]
      tokens.shift
    else
      fail "syntax NAME"
    end
    r = [:".syntax", name]

    while tokens[0] != :".end"
      eq, tokens = equation(tokens)
      #pp eq
      if eq
        r << eq
      else
        break
      end
    end

    tokens = expect(:".end", tokens)
    return r
  end

  def id?(tok)
    tok.is_a?(Symbol) && tok.to_s =~ /^[A-Za-z][A-Za-z0-9]*$/
  end

  def command?(tok)
    tok == :"$" ||
      (tok.is_a?(Symbol) && tok.to_s =~ /^\./)
  end

  # tokens -> tokens
  def equation(tokens)
    if id?(tokens[0])
      lhs = tokens[0]
      tokens.shift
    else
      fail "equation LHS"
    end

    tokens = expect(:"=", tokens)

    sel, tokens = ex1(tokens)
    #pp tokens
    tokens = expect(:";", tokens)

    return [:"=", lhs, sel], tokens
  end

  def ex1(tokens)
    # p [:ex1, tokens.join(" ")]
    selection = [:"/"]
    while true
      exp, tokens = ex2(tokens)
      if exp
        selection << exp
        if tokens[0] == :"/"
          tokens.shift
          next
        else
          break
        end
      else
        fail "expression expected"
      end
    end
    return selection, tokens
  end

  def ex3(tokens)
    #p [:ex3, tokens]
    if id?(tokens[0])
      return tokens.shift, tokens
    elsif tokens[0].is_a?(String)
      return tokens.shift, tokens
    elsif tokens[0] == :"$"
      tokens.shift
      ex, tokens = ex3(tokens)
      return [:"$", ex], tokens
    elsif tokens[0] == :"("
      tokens.shift
      ex, tokens = ex1(tokens)
      tokens = expect(:")", tokens)
      return ex, tokens
    elsif tokens[0] == :".string" ||
          tokens[0] == :".empty" ||
          tokens[0] == :".number" ||
          tokens[0] == :".id"
      return [tokens.shift], tokens
    else
      return nil, tokens
    end
  end

  def output(tokens)
    if tokens[0] == :".out"
      o, tokens = out(tokens)
      return o, tokens
    elsif tokens[0] == :".label"
      l, tokens = label(tokens)
      return l, tokens
    else
      return nil, tokens
    end
  end

  def ex2(tokens)
    # p [:ex2, tokens.join(" ")]
    r = [:prog]

    while true
      ex, tokens = ex3(tokens)
      #p({ex: ex, tokens: tokens})
      if ex.nil?
        ex, tokens = output(tokens)
        if ex.nil?
          break
        end
      end
      r << ex
    end
    return r, tokens
  end

  def out(tokens)
    tokens = expect(:".out", tokens)
    tokens = expect(:"(", tokens)

    terms = []
    while true
      if tokens[0] == :"*1"
        terms << tokens.shift
      elsif tokens[0] == :"*2"
        terms << tokens.shift
      elsif tokens[0] == :"*"
        terms << tokens.shift
      elsif tokens[0].is_a?(String)
        terms << tokens.shift
      else
        break
      end
    end

    tokens = expect(:")", tokens)
    return [:".out", *terms], tokens
  end

  def label(tokens)
    tokens = expect(:".label", tokens)
    l = tokens.shift
    return [:".label", l], tokens
  end

  def expect(tok, tokens)
    if tok == tokens[0]
      return tokens[1..-1]
    else
      fail "#{tok.inspect} expected but got #{tokens[0].inspect}"
    end
  end

  def run
  end


  def match(pattern, tokens)
    prefix = []
    pattern.each_with_index do |sub, i|
      if sub === tokens[i]
        prefix << tokens[i]
      end
    end
    if prefix.size == pattern.size
      return prefix, tokens[prefix.size..-1]
    else
      return nil, tokens
    end
  end
end

module Execution
  module_function

  @@env = {}

  def do_syntax(syntax, input)
    @@input = input
    @@output = ""
    @@label1 = nil
    @@label2 = nil
    @@label_counter = 0

    entry_point = syntax[1]
    syntax[2..-1].each do |eq|
      define_equation(eq)
    end
    call_equation(entry_point)

    print @@output
  end

  def define_equation(eq)
    name = eq[1]
    body = eq[2]
    @@env[name] = body
  end

  def call_equation(name)
    prog = @@env[name]
    fail "no eq. named #{name.inspect}" unless prog
    back1, back2 = @@label1, @@label2
    @@label1, @@label2 = nil, nil
    r = dispatch_exp(prog)
    @@label1, @@label2 = back1, back2
    return r
  end

  def _print(x)
    @@output.concat(x)
  end

  def _puts(x = "")
    @@output.concat(x)
    @@output.concat("\n")
  end

  def gen_label
    l, i = @@label_counter.divmod(100)
    @@label_counter += 1
    "%c%02d" % [("A".ord + l).chr, i + 1]
  end

  def dispatch_exp(exp)
    # p [:dispatch, exp, @@input]
    # STDIN.gets
    case exp
    when Array
      case exp[0]
      when :prog
        exp[1..-1].each do |sub|
          #p [:sub, sub]
          unless dispatch_exp(sub)
            #p :return_false
            return false
          end
        end
        return true
      when :"$"
        #p :"$"
        prog = exp[1]
        while true
          back = @@input.dup
          unless dispatch_exp(prog)
            @@input = back
            break
          end
        end
        return true
      when :".out"
        #p exp
        _print " "*6
        exp[1..-1].each do |sub|
          _print " "
          case sub
          when String
            _print sub
          when :"*"
            _print @@last_symbol
          when :"*1"
            @@label1 ||= gen_label
            _print @@label1
          when :"*2"
            @@label2 ||= gen_label
            _print @@label2
          else
            p [:sub, sub]
          end
        end
        _puts
        return true
      when :"/"
        #p :"/"
        exp[1..-1].each do |sub|
          iback = @@input.dup
          oback = @@output.dup
          r = dispatch_exp(sub)
          if r
            return true
          else
            @@input = iback
            @@oback = oback
          end
        end
        return false
      when :".id"
        if @@input =~ /\A\s*([A-Za-z][A-Za-z0-9]*)/
          @@last_symbol = $1
          @@input = $'
          return true
        else
          return false
        end
      when :".number"
        if @@input =~ /\A\s*(\d+\.?\d+|\d)/
          @@last_symbol = $1
          @@input = $'
          return true
        else
          return false
        end
      when :".string"
        if @@input =~ /\A\s*('[^']*')/
          @@last_symbol = $1
          @@input = $'
          return true
        else
          return false
        end
      when :".label"
        #p [:label]
        exp[1..-1].each do |item|
          case item
          when String
            _print item
          when :"*"
            _print @@last_symbol
          when :"*1"
            @@label1 ||= gen_label
            _print @@label1
          when :"*2"
            @@label2 ||= gen_label
            _print @@label2
          end
        end
        _puts
        return true
      when :".empty"
        return true
      else # command
            fail "unimplemented command #{exp[0]}"
      end
    when Symbol
      #p [:call, exp]
      call_equation(exp)
    when String
      #p @@input
      #p [:string, exp]
      if @@input =~ /\A\s*#{Regexp.escape(exp)}/
        @@input = $'
        true
      else
        false
      end
    end
  end

end

unless ARGV.size >= 1
  STDERR.puts "Usage: meta-ii-interpreter COMPILER.m2 [SOURCE]"
  exit 1
end
ast = Parsing.syntax(tokenize(File.read(ARGV.shift)))
#pp ast
input = ARGF.read
Execution.do_syntax(ast, input)
