#    This file is part of Metasm, the Ruby assembly manipulation suite
#    Copyright (C) 2006-2009 Yoann GUILLOT
#
#    Licence is LGPL, see LICENCE in the top-level directory


require 'metasm/main'

module Metasm

# a Renderable element has a method #render that returns an array of [String or Renderable]
module Renderable
	def to_s
		render.join
	end

	# yields each Expr seen in #render (recursive)
	def each_expr
		r = proc { |e|
			case e
			when Expression
				yield e
				r[e.lexpr] ; r[e.rexpr]
			when Renderable
				e.render.each { |re| r[re] }
			end
		}
		r[self]
	end
end


class Instruction
	include Renderable
	def render
		@cpu.render_instruction(self)
	end
end

class Label
	include Renderable
	def render
		[@name + ':']
	end
end

class CPU
	# renders an instruction
	# may use instruction-global properties to render an argument (eg specify pointer size if not implicit)
	def render_instruction(i)
		r = []
		r << i.opname
		r << ' '
		i.args.each { |a| r << a << ', ' }
		r.pop
		r
	end

	# ease debugging in irb
	def inspect
		"#<#{self.class}:#{'%x' % object_id} ... >"
	end
end

class Expression
	include Renderable
	attr_accessor :render_info
	def render
		return Expression[@lexpr, :-, -@rexpr].render if @op == :+ and @rexpr.kind_of?(::Numeric) and @rexpr < 0
		l, r = [@lexpr, @rexpr].map { |e|
			if e.kind_of? Integer
				if e < 0
					neg = true
					e = -e
				end
				if render_info and @render_info[:char] and [9,10,13,*0x20..0x7e].include?(e)
					if e == ?'.ord; e = "'\\''"
					else e = e.chr.inspect.gsub('"', "'")
					end
				elsif e < 10; e = e.to_s
				else
					e = '%xh' % e
					e = '0' << e unless (?0..?9).include? e[0]
				end
				e = '-' << e if neg
			end
			e
		}
		nosq = {:* => [:*], :+ => [:+, :-, :*], :- => [:+, :-, :*]}
		l = ['(', l, ')'] if @lexpr.kind_of? Expression and not nosq[@op].to_a.include?(@lexpr.op)
		nosq[:-] = [:*]
		r = ['(', r, ')'] if @rexpr.kind_of? Expression and not nosq[@op].to_a.include?(@rexpr.op)
		op = @op if l or @op != :+
		[l, op, r].compact
	end
end
end
