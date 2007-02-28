#!/usr/bin/env ruby

require 'metasm/ia32/parse'
require 'metasm/ia32/encode'
require 'metasm/exe_format/elf'

cpu = Metasm::Ia32.new
prog = Metasm::Program.new cpu

prog.parse DATA.read

prog.encode
PT_GNU_STACK = 0x6474e551
data = Metasm::ELF.encode prog, 'unstripped' => true, 'elf_interp' => '/lib/ld-linux.so.2', 'additional_segments' => [[PT_GNU_STACK, 0, 0, 0, 0, %w[R W], 0]]

File.open('testelf', 'wb', 0755) { |fd| fd.write data }

__END__
sys_write equ 4
sys_exit  equ 1
stdout    equ 1

syscall macro nr
 mov eax, nr // the syscall number goes in eax
 int 80h
endm

.text
.data
toto:
# if 0 + 1 > 0
 db "toto\n"
#elif defined(STR)
 db STR
#else
 db "lala\n"
#endif
toto_len equ $-toto

.text
start:
 mov ebx, stdout
 mov ecx, toto
 mov edx, toto_len
 syscall(sys_write)

//.import 'libc.so.6' '_exit', libexit
// push 0
// call libexit
 xor ebx, ebx
 syscall(sys_exit)
