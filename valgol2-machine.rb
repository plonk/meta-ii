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
  def initialize(memory, printer)
    @switch  = false
    @memory  = memory
    @sp = memory.size
    memory.concat([nil]*1000)
    @printer = printer
    @ip = 0
    @running = false
    @stack1 = nil
    @flag = nil
    @save = nil
  end

  def address?(v)
    v.is_a?(Array) && v[0] == :a
  end

  def getmem(adr)
    fail unless address?(adr)
    @memory[adr[1]]
  end

  def setmem(adr, v)
    #p [:setmem, adr, v]
    fail unless address?(adr)
    @memory[adr[1]] = v
  end

  # ---------------------------

  def ld(addr)
    while address?(getmem(addr))
      addr = getmem(addr)
    end

    @memory[@sp] = addr; @sp += 1

    @ip += 1
  end

  def ldl(n)
    @memory[@sp] = n; @sp += 1

    @ip += 1
  end

  def set
    @memory[@sp] = 1; @sp += 1

    @ip += 1
  end

  def rst
    @memory[@sp] = 0; @sp += 1

    @ip += 1
  end

  def st
    setmem(@memory[@sp-1], @stack1)
    @sp -= 1

    @ip += 1
  end

  def deref!(adr)
    unless address?(adr)
      adr = [:a,adr]
    end

    while address?(getmem(adr))
      setmem(adr, getmem(getmem(adr)))
    end
  end

  def ads
    deref!(@sp-1)
    a = @memory[@sp-1]
    b = getmem(@memory[@sp-2])
    @stack1 = a+b
    setmem(@memory[@sp-2], @stack1)

    @sp -= 2
    @ip += 1
  end

  def sst
    deref!(@sp-1)
    @stack1 = @memory[@sp-1]

    setmem(getmem([:a,@sp-2]), @stack1)
    @sp -= 2
    @ip += 1
  end

  def rsr
    @memory[@sp] = @stack1
    @sp += 1
    @ip += 1
  end

  def add
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = @memory[@sp-1] + @memory[@sp-2]
    @sp -= 1
    @ip += 1
  end

  def sub
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = @memory[@sp-2] - @memory[@sp-1]
    @sp -= 1
    @ip += 1
  end

  def mlt
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = @memory[@sp-1] * @memory[@sp-2]
    @sp -= 1
    @ip += 1
  end

  def div
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = @memory[@sp-2].fdiv @memory[@sp-1]
    @sp -= 1
    @ip += 1
  end

  def neg
    deref!(@sp-1)
    @memory[@sp-1] = -@memory[@sp-1]
    @ip += 1
  end

  def whl
    @memory[@sp-1] = Math.floor(@memory[@sp-1])
    @ip += 1
  end

  def not
    if @memory[@sp-1] == 0
      @memory[@sp-1] = 1
    elsif @memory[@sp-1] == 1
      @memory[@sp-1] = 0
    else
      fail "not"
    end
    @ip += 1
  end

  def leq
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = if @memory[@sp-2] <= @memory[@sp-1] then
                       1
                     else
                       0
                     end
    @sp -= 1
    @ip += 1
  end

  def les
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = if @memory[@sp-2] < @memory[@sp-1] then
                       1
                     else
                       0
                     end
    @sp -= 1
    @ip += 1
  end

  def equ
    deref!(@sp-1)
    deref!(@sp-2)
    @memory[@sp-2] = if @memory[@sp-2] == @memory[@sp-1] then
                       1
                     else
                       0
                     end
    @sp -= 1
    @ip += 1
  end

  def b(adr)
    @ip = adr[1]
  end

  def bt(adr)
    if @memory[@sp-1] != 0
      @ip = adr[1]
    else
      @ip += 1
    end
  end

  def bf(adr)
    if @memory[@sp-1] == 0
      @ip = adr[1]
    else
      @ip += 1
    end
  end

  def btp(adr)
    if @memory[@sp-1] != 0
      @ip = adr[1]
    else
      @ip += 1
    end
    @sp -= 1
  end

  def bfp(adr)
    if @memory[@sp-1] == 0
      @ip = adr[1]
    else
      @ip += 1
    end
    @sp -= 1
  end

  def atoi(adr)
    _a, i = adr
    fail "Not an address: #{adr.inspect}" unless _a == :a
    return i
  end

  # フラグレジスタからスタックのトップまでをサブルーチンにコピーする。
  # サブルーチンのアドレスは[フラグ-2]。
  # スタック上の引数をポップして、フラグをポップしてフラグレジスタを復元する。
  # サブルーチンのアドレスをリターンアドレスに変更する。
  # サブルーチンのコードの始まるアドレスにジャンプ。
  def cll
    subadr = atoi(@memory[atoi(@flag) - 2])
    pt = subadr + 1
    (atoi(@flag) .. (@sp - 1)).each do |adr|
      if @memory[pt] == nil
        fail "Error: too many arguments"
      end
      @memory[pt] = @memory[adr]
      pt += 1
    end
    if @memory[pt] != nil
      fail "Error: too few arguments"
    end

    @sp = atoi(@flag)
    @flag = @memory[@sp-1]
    @sp -= 1
    @memory[@sp-1] = [:a, @ip + 1]

    @ip = pt + 1
  end

  def ldf
    @memory[@sp] = @flag
    @sp += 1
    @flag = [:a, @sp]

    @ip += 1
  end

  def r(padr)
    _a, xadr = @memory[@sp-1]
    @memory[@sp-1] = padr
    @ip = xadr
  end

  def aia
    _a, adr = @memory[@sp-2]
    @memory[@sp-2] = [:a, (adr + @memory[@sp-1]).to_i]
    @sp -= 1
    @ip += 1
  end

  def flp
    @memory[@sp-1], @memory[@sp-2] = @memory[@sp-2], @memory[@sp-1]
    @ip += 1
  end

  def pop
    @sp -= 1
    @ip += 1
  end

  def edt(str)
    deref!(@sp-1)
    n = @memory[@sp-1].round
    @printer.set_column(n)
    @printer.print(str)
    @sp -= 1 # POPする？
    @ip += 1
  end

  def pnt
    @printer.output
    @printer.clear
    @ip += 1
  end

  def ejt
    @printer.clear
    @printer.output
    @ip += 1
  end

  def red
    deref!(@sp-1)
    n = @memory[@sp-1]
    fail "RED: address required" unless @memory[@sp-2]
    _a, adr = @memory[@sp-2]
    @sp -= 2

    (1 .. n).each do |i|
      print "NUMBER [%d/%d]? " % [i, n]
      @memory[adr + i - 1] = STDIN.gets.to_f
    end
    @ip += 1
  end

  def wrt
    deref!(@sp-1)
    n = @memory[@sp-1]
    _a, adr = @memory[@sp-2]
    @sp -= 2

    (adr .. (adr + n - 1)).each do |pt|
      STDOUT.print "%g " % [@memory[pt]]
    end
    STDOUT.puts
    @ip += 1
  end

  def hlt
    @running = false
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

def execute(mem)
  m = Machine.new(mem, Printer.new)
  m.run
end

if ARGV.size != 1
  STDERR.puts("Usage: valgol2-machine.rb PROGRAM")
  exit 1
end
program = ARGV.shift
execute(eval(File.read(program)))
