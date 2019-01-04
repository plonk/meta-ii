$print_area = ""
$stack = []
$ip = 0
$mem = []
$running = false

def edt(str)
  start = $stack[-1].round
  if start > $print_area.size
    $print_area.concat " " * ((start - 1) - $print_area.size)
  end
  str.each_char.with_index do |c, i|
    $print_area[start + i -1] = c
  end
  $stack.pop
  $ip += 1
end

def pnt
  puts $print_area
  $print_area = ""
  $ip += 1
end

def ldl(literal)
  $stack.push(literal)
  $ip += 1
end

def ld(addr)
  $stack.push($mem[addr])
  $ip += 1
end

def st(addr)
  $mem[addr] = $stack.pop
  $ip += 1
end

def mlt
  a, b = $stack.pop(2)
  $stack.push(a*b)
  $ip += 1
end

def add
  a, b = $stack.pop(2)
  $stack.push(a+b)
  $ip += 1
end

def equ
  a, b = $stack.pop(2)
  if (a-b).abs < 0.00001
    $stack.push(1)
  else
    $stack.push(0)
  end
  $ip += 1
end

def b(addr)
  $ip = addr
end

def bfp(addr)
  fail "unimp"
end

def btp(addr)
  if $stack.pop == 1
    $ip = addr
  else
    $ip += 1
  end
end

def hlt
  $running = false
end

def run(prog)
  $mem = prog
  $running = true

  while $running
    self.send(*$mem[$ip])
  end
end

# run([
#       [:b, 2],
#       nil, # X = 1
#       [:ldl, 0], # A01 = 2
#       [:st, 1], # X
#       [:ld, 1], # A02 = 4
#       [:ldl, 3],
#       [:equ],
#       [:btp, 22],
#       [:ld, 1],
#       [:ld, 1],
#       [:mlt],
#       [:ldl, 10],
#       [:mlt],
#       [:ldl, 1],
#       [:add],
#       [:edt, "*"],
#       [:pnt],
#       [:ld, 1],
#       [:ldl, 0.1],
#       [:add],
#       [:st, 1],
#       [:b, 4],
#       [:hlt],
#     ])

run(eval(ARGF.read))

