class Printer
  def initialize
    @buffer = ' ' * 120
    @col = 8
  end

  def clear
    @buffer.replace(' ' * 120)
  end

  def output
    puts @buffer.rstrip
  end

  def set_column(n)
    @col = n
  end

  def print(str)
    #p [:str, str]
    lastpos = @col-1
    pos = lastpos
    while pos < (@col-1)+str.size && pos < 120
      @buffer[pos] = str[pos - lastpos]
      pos += 1
    end
    @col = pos + 1
  end

end

class Machine
  def initialize(memory, input, printer)
    @switch  = false
    @memory  = memory
    @input   = input
    @printer = printer
    @ip = memory[0]
    @stack = []
    @label_counter = 0
    @running = false
    @deleted = ""
  end

  def gen_label
    l, i = @label_counter.divmod(100)
    @label_counter += 1
    "%c%02d" % [("A".ord + l).chr, i + 1]
  end

  def tst(str)
    # p [:@input, @input]
    if @input =~ /\A\s+/
      @input = $'
    end
    if @input =~ /\A#{Regexp.escape(str)}/
      @deleted = $&
      STDERR.puts "#{@deleted} DELETED" if $DEBUG
      @input = $'
      @switch = true
    else
      @switch = false
    end
    @ip += 1
  end

  def id
    if @input =~ /\A\s+/
      @input = $'
    end
    if @input =~ /\A[A-Za-z][A-Za-z0-9]*/
      @deleted = $&
      STDERR.puts "#{@deleted} DELETED" if $DEBUG
      @input = $'
      @switch = true
    else
      @switch = false
    end
    @ip += 1
  end

  def num
    if @input =~ /\A\s+/
      @input = $'
    end
    if @input =~ /\A(\d+\.?\d+|\d)/
      @deleted = $1
      STDERR.puts "#{@deleted} DELETED" if $DEBUG
      @input = $'
      @switch = true
    else
      @switch = false
    end
    @ip += 1
  end

  def sr
    if @input =~ /\A\s+/
      @input = $'
    end
    if @input =~ /\A'[^']*'/
      @deleted = $&
      STDERR.puts "#{@deleted} DELETED" if $DEBUG
      @input = $'
      @switch = true
    else
      @switch = false
    end
    @ip += 1
  end

  def cll(addr)
    if @stack.last(2) == [nil,nil]
      @stack.push(nil)
      flag = true
    else
      @stack.push(nil, nil, nil)
      flag = false
    end
    @stack[-3] = [@ip + 1, flag]
    @ip = addr
  end

  def r
    if @stack.size == 0
      @running = false
      return
    end

    ret, flag = @stack[-3]
    if flag
      @stack.pop
      @stack[-1] = nil
      @stack[-2] = nil
    else
      @stack.pop(3)
    end
    @ip = ret
  end

  def set
    @switch = true
    @ip += 1
  end

  def b(addr)
    @ip = addr
  end

  def bt(addr)
    if @switch
      @ip = addr
    else
      @ip += 1
    end
  end

  def bf(addr)
    if @switch
      @ip += 1
    else
      @ip = addr
    end
  end

  def be
    unless @switch
      STDERR.puts "ERROR"
      @running = false
    end
    @ip += 1
  end

  def cl(str)
    @printer.print(str)
    @printer.print(" ")
    @ip += 1
  end

  def ci
    @printer.print(@deleted)
    @ip += 1
  end

  def gn1
    @stack[-2] ||= gen_label
    @printer.print(@stack[-2])
    @printer.print(" ")
    @ip += 1
  end

  def gn2
    @stack[-1] ||= gen_label
    @printer.print(@stack[-1])
    @printer.print(" ")
    @ip += 1
  end

  def lb
    @printer.set_column(1)
    @ip += 1
  end

  def out
    @printer.output
    @printer.clear
    @printer.set_column(8)
    @ip += 1
  end

  def run
    @running = true
    while @running
      inst = @memory[@ip]
      p [@ip, inst] if $DEBUG
      self.send(*inst)
    end
  end

end

def exec(mem, input)
  m = Machine.new(mem, input, Printer.new)
  m.run
end

exec(eval(STDIN.read), ARGF.read)
