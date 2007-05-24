require 'metasm/main'

module Metasm

module Renderable
	def to_s
		render.join
	end
end


class Instruction
	include Renderable
	def render
		@cpu.render_instruction(self)
	end
end

class CPU
	def render_instruction(i)
		r = []
		r << @opname
		if not @args.empty?
			r << ' '
			@args.each { |a|
				r << a << ', '
			}
			r.pop
		end
		r
	end
end

class Expression
	include Renderable
	def render
		l = @lexpr
		r = @rexpr
		if l.kind_of? Integer
			l = '%xh' % l
			l = '0' << l unless (?0..?9).include? l[0]
		end
		if r.kind_of? Integer
			r = '%xh' % r
			r = '0' << r unless (?0..?9).include? r[0]
		end
		if @op == :+ and not l
			[r]
		else
			['(', l, @op, r, ')']
		end
	end
end

class Indirection
	include Renderable
	def render
		[@type.inspect, ' ptr [', @target, ']']
	end
end
end
