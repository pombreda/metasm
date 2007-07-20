#    This file is part of Metasm, the Ruby assembly manipulation suite
#    Copyright (C) 2007 Yoann GUILLOT
#
#    Licence is LGPL, see LICENCE in the top-level directory


require 'metasm/main'
require 'metasm/preprocessor'

module Metasm
# c parser
# bad reference at http://www.csci.csusb.edu/dick/samples/c.syntax.html
class CParser
	class Scope
		# name => obj
		attr_accessor :variable
		attr_accessor :type
		attr_accessor :struct
		attr_accessor :outer	# outer scope

		def initialize(outer=nil)
			@variable, @type, @struct = {}, {}, {}
			@outer = outer
		end

		def variable_ancestors
			(outer ? outer.variable_ancestors : {}).merge @variables
		end
		def type_ancestors
			(outer ? outer.type_ancestors : {}).merge @types
		end
		def struct_ancestors
			(outer ? outer.struct_ancestors : {}).merge @struct
		end
	end

	class Block
		attr_accessor :scope
		# sequence of CExpr/If/While/DoWhile/For/Continue/Break/Return/Goto/Switch/Case/Label
		attr_accessor :statements

		def initialize(outer = nil)
			@statements = []
			@scope = Scope.new(outer.outer if outer)
		end
	end

	class Declaration
		attr_accessor :attributes
	end

	class Variable < Declaration
		attr_accessor :type, :initializer
	end

	class Type < Declaration
		attr_accessor :qualifier
		# not instanciable
	end
	class BaseType < Type
		attr_accessor :modifier
	end
	class Function < Type
		attr_accessor :return_type
		# ary [[name, Variable], [..]]
		attr_accessor :args
	end
	class Struct < Type
		# hash name => Variable
		attr_accessor :member
		# hash name => offset
		attr_accessor :members_offset
		# hash name => nrbits
		attr_accessor :bits
	end
	class Union < Type
		attr_accessor :members
	end
	class Enum < Type
		# hash name => value
		attr_accessor :values
	end
	class Pointer < Type
		attr_accessor :type
	end
	class Array < Type
		attr_accessor :length
	end

	class If
		# expression
		attr_accessor :test
		# blocks
		attr_accessor :then, :else
	end
	class For
		# expressions
		attr_accessor :init, :test, :iter
		attr_accessor :scope, :body
		# scope used for init
	end
	class While
		attr_accessor :test
		attr_accessor :body
	end
	class DoWhile < While
	end
	class Switch
		attr_accessor :test, :body
	end

	class Continue
	end
	class Break
	end
	class Goto
		attr_accessor :target
	end
	class Return
		# CExpr
		attr_accessor :value
	end
	class Label
		attr_accessor :name
	end
	class Case
		attr_accessor :case
	end

	class CExpression
		# op may be :,, :., :->, :funcall (funcname, :funcall, [arglist]), :cast (type, :cast, expr)
		# XXX cast to fnptr
		attr_accessor :lexpr, :op, :rexpr
		def initialize(l, o, r)
			@lexpr, @op, @rexpr = l, o, r
		end
	end

	attr_accessor :lexer, :toplevel
	def initialize
		@lexer = Preprocessor.new(self)
		@toplevel = Block.new
	end

	# creates a new CParser, parses all top-level statements
	def self.parse(text, file='unknown', lineno=1)
		c = new
		c.lexer.feed text, file, lineno
		while not c.lexer.eos?
			c.parse_toplevel
		end
		c
	end

	# skip all space/eol, returns the next token or unread it
	def skipspaces(unread=false)
		nil while tok = @lexer.readtok and (tok.type == :space or tok.type == :eol)
		unread ? @lexer.unreadtok(tok) : tok
	end

	# check if a word is an invalid variable name
	def isreserved(w)
		@type[w] or %w[struct union enum register const volatile static extern].include? a.raw
	end

	# typedef / var declaration/definition / function decl/def
	# XXX __attributes__ ?
	# root of the state machine
	def parse_toplevel
		return if not tok = skipspaces
		raise tok if tok.type != :string

		case tok.raw
		when 'typedef'
			parse_typedef @toplevel.scope
		when 'union'
			parse_union @toplevel.scope
		when 'struct'
			parse_struct @toplevel.scope
		when 'enum'
			parse_enum @toplevel.scope
		else
			parse_type @toplevel.scope
		end
	end

	def parse_typedef(scope)
		raise @lexer if not tok = skipspaces
	end

	def parse_union(scope)
		raise @lexer if not tok = skipspaces
	end

	def parse_struct(scope)
		raise @lexer if not tok = skipspaces
		if tok.type == :string
			name = tok.raw
			raise tok, 'reserved struct name' if isreserved(name)
		end
		# XXX	ntok = skipspaces
	end

	def parse_enum(scope)
		raise @lexer if not tok = skipspaces
	end

	# TODO don't handle fntype for now
	def parse_type(scope)
		raise @lexer if not tok = skipspaces

	end

# XXX undone XXX #
# XXX undone XXX #
# XXX undone XXX #
# XXX undone XXX #

			u = parse_union

			parse_union @toplevel.scope
			type = parse_union tok
			ntok = readtok(tok)
			return if ntok.type == :punct and ntok.raw == ';'
			@lexer.unreadtok ntok
		when 'struct'
			type = parse_struct tok
			ntok = readtok(tok)
			return if ntok.type == :punct and ntok.raw == ';'
			@lexer.unreadtok ntok
		else
			if not reserved(tok.raw)
				type = Type.new('int')
				@lexer.unreadtok tok
			else
				type = parse_type tok
			end
		end

		loop do
			name = readtok(tok, :string)
			case readtok(name, :punct).raw
			when '('	# function declaration/definition
				func = Function.new
				func.name = name
				func.return_type = type
				func.args = []
				seentype = false
				# read argument list
				loop do
					func.args << Variable.new
					a = readtok(name, :string)
					if not reserved(a.raw)
						func.args.last.name = a
					else
						seentype = true
						func.args.last.type = parse_type a
					end
					ntok = readtok(tok)
					if not oldstyledef and ntok.type == :string
						func.args.last.name = ntok
						ntok = readtok(tok)
					end
					raise name if ntok.type != :punct or (ntok.raw != ',' and ntok.raw != ')')
					break if ntok.raw == ')'
				end
				if not seentype
					# oldstyle: int toto(a, b, c) int a; int b; double c; { kikoo lol }
					loop do
						ntok = readtok(tok)
						if ntok.type == :punct and ntok.raw == '{'
							@lexer.unreadtok ntok
							break
						end
						raise name if ntok.type != :string
						atype = parse_type(ntok)
						aname = readtok(name, :string)
						if not arg = func.args.find { |a| a.name.raw == aname.raw } or arg.type != atype
							raise name, 'syntax error'
						end
						arg.type = atype
						raise name if readtok(name, :punct).raw != ';'
					end
				end
				func.args.each { |a| a.type ||= Type.new('int') }
				# check redefinition
				if o = @curscope.find_var(name.raw)
					if not o.kind_of? Function or o.body or o.return_type != func.return_type or
					(o.args.length > 0 and func.args.length > 0 and (o.args.length != func.args.length or
					(o.args.zip(func.args).any? { |t1, t2| t1 != t2 })))
						raise name, 'bad redeclaration'
					end
				end
				@curscope.variables[name.tok] = func
				# read body
				case readtok(name, :punct).raw
				when ',': next
				when ';': break
				when '{'
					func.scope = @curscope = Scope.new(@curscope)
					loop do
						ntok = readtok(name)
						break if ntok.type == :punct and ntok.raw == '}'
						@lexer.unreadtok ntok
						@curscope << parse_c_statement(ntok)
					end
					@curscope = @curscope.parent
					break
				else raise name
				end

			when '='	# variable initialization
				raise name, 'redefinition' if v = @curscope.variables[name] and (v.initializer or v.type != type)
				raise name if type.modifiers.include? 'extern'
				var = Variable.new
				var.name = name
				var.type = type
				var.initializer = parse_initializer(name, var)
				@curscope.variables[name] = var
			when ','	# next variable
				raise name, 'redefinition' if v = @curscope.variables[name] and (v.initializer or v.type != type)
				var = Variable.new
				var.name = name
				var.type = type
				@curscope.variables[name] = var
			when ';'	# done
				break
			else raise name
			end
		end
	end

	def parse_typedef(tok)
		type = parse_type(tok)
		newtype = readtok(tok, :string)
		raise tok if readtok(tok, :punct).raw != ';'
		@type[newtype.raw] = type
	end

	def parse_struct(tok)
		ntok = readtok(tok)
		if ntok.type == :string
			name = ntok.raw
			ntok = readtok(tok, :punct)
			if ntok.raw == ';'
				s = Struct.new
				s.name = name
				@type["struct #{name.raw}"] ||= s
				return s
			end
		end
		raise tok if ntok.raw != '{'
		s = Struct.new
		s.name = name
		s.members = []
		@type["struct #{name.raw}"] = s if name
		loop do
			ntok = readtok(tok)
			if ntok.type == :punct and ntok.raw == '}'
				break
			end
			s.members << Variable.new
			s.members.last.type = parse_type(ntok)
			s.members.last.name = readtok(tok, :string)
			ntok = readtok(tok, :punct)
			if ntok.raw == ':'
				s.bits ||= {}
				s.bits[s.members.last.name.raw] = readtok(tok, :string).raw.to_i
				ntok = readtok(tok, :punct)
			end
			raise tok if readtok(tok, :punct).raw != ';'
		end
		s
	end

	def parse_union(tok)
		ntok = readtok(tok)
		if ntok.type == :string
			name = ntok.raw
			ntok = readtok(tok, :punct)
			if ntok.raw == ';'
				u = Union.new
				u.name = name
				@type["union #{name.raw}"] ||= u
				return u
			end
		end
		raise tok if ntok.raw != '{'
		u = Union.new
		u.name = name
		u.members = []
		@type["union #{name.raw}"] = u if name
		loop do
			ntok = readtok(tok)
			if ntok.type == :punct and ntok.raw == '}'
				break
			end
			u.members << Variable.new
			u.members.last.type = parse_type(ntok)
			u.members.last.name = readtok(tok, :string)
			raise tok if readtok(tok, :punct).raw != ';'
		end
		u
	end

	def parse_type(tok)
		# XXX int (*foo)(void); : we read type and unreadtok name
	end

	def parse_initializer(tok, var)
		ntok = readtok(tok)
		if ntok.type == :punct and ntok.raw == '{'	# struct/array initialization
			members = []
			if var.type.type.kind_of? Struct
				members = var.type.type.members
			end
			type = var.type
			ret = []
			loop do
				ntok = readtok(tok)
				if ntok.type == :punct and ntok.type == '.'
					raise tok if not members.include?((name = readtok(tok, :string)).raw)
					raise tok if readtok(tok, :punct).raw != '='
					ret << CExpression.new(name.raw, :'=', parse_c_expression(name))
				else
					@lexer.unreadtok ntok
					ret << parse_c_expression(tok)
				end
				case readtok(tok, :punct).raw
				when ','
				when '}': break
				else raise tok
				end
			end
			ret
		else parse_c_expression(tok)
		end
	end

	def parse_c_expression(tok)
		p1 = parse_c_value
		loop do
			op = readop
			p2 = parse_c_value
		end
	end

	def parse_c_statement(tok)
		case ntok
		when 'if'
		when 'switch'
		when 'while'
		when 'do'
		when 'for'
		when 'asm'
		else
			if reserved ntok
				parse_def
			end
		end
	end
end

class Expression
	class << self
		# key = operator, value = hash regrouping operators of lower precedence
		OP_PRIO = [[:'||'], [:'&&'], [:'<', :'>', :'<=', :'>=', :'==', :'!='],
			[:|], [:^], [:&], [:<<, :>>], [:+, :-], [:*, :/, :%]].inject({}) { |h, oplist|
			lessprio = h.keys.inject({}) { |hh, op| hh.update op => true }
			oplist.each { |op| h[op] = lessprio }
			h }


		# reads an operator from the lexer, returns the corresponding symbol or nil
		def readop(lexer)
			if not tok = lexer.readtok or tok.type != :punct
				lexer.unreadtok tok
				return
			end

			if tok.value
				if OP_PRIO[tok.value]
					return tok
				else
					lexer.unreadtok tok
					return
				end
			end

			op = tok
			case op.raw
			# may be followed by itself or '='
			when '>', '<'
				if ntok = lexer.nexttok and ntok.type == :punct and (ntok.raw == op.raw or ntok.raw == '=')
					op.raw << lexer.readtok.raw
				end
			# may be followed by itself
			when '|', '&'
				if ntok = lexer.nexttok and ntok.type == :punct and ntok.raw == op.raw
					op.raw << lexer.readtok.raw
				end
			# must be followed by '='
			when '!', '='
				if not ntok = lexer.nexttok or ntok.type != :punct and ntok.raw != '='
					lexer.unreadtok tok
					return
				end
				op.raw << lexer.readtok.raw
			# ok
			when '^', '+', '-', '*', '/', '%'
			# unknown
			else
				lexer.unreadtok tok
				return
			end
			op.value = op.raw.to_sym
			op
		end

		# parses an integer/a float, sets its tok.value, consumes&aggregate necessary following tokens (point, mantissa..)
		# handles $/$$ special asm label name
		def parse_intfloat(lexer, tok)
			if tok.raw == '$' and lexer.program
				if not (l = lexer.program.cursource.last).kind_of? Label
					l = Label.new(lexer.program.new_label('instr_start'))
					l.backtrace = tok.backtrace.dup
					lexer.program.cursource << l
				end
				tok.value = l.name
				return
			elsif tok.raw == '$$' and lexer.program
				if not (l = lexer.program.cursource.first).kind_of? Label
					l = Label.new(lexer.program.new_label('section_start'))
					l.backtrace = tok.backtrace.dup
					lexer.program.cursource.unshift l
				end
				tok.value = l.name
				return
			end

			if not tok.value and tok.type == :punct and tok.raw == '.'
				# bouh
				ntok = lexer.readtok_nopp
				lexer.unreadtok ntok
				if ntok and ntok.type == :string and ntok.raw =~ /^[0-9][0-9e_]*$/ and ntok.raw.count('e') <= 1
					point = tok.dup
					lexer.unreadtok point
					tok.raw = '0'
					tok.type = :string
				end
			end

			return if tok.value or not (?0..?9).include? tok.raw[0]

			case tok.raw
			when /^0b([01_]+)$/, /^([01_]+)b$/
				tok.value = $1.to_i(2)
			when /^(0[0-7_]+)$/
				tok.value = $1.to_i(8)
			when /^0x([a-fA-F0-9_]+)$/, /^([0-9][a-fA-F0-9_]*)h$/
				tok.value = $1.to_i(16)
			when /^[0-9_]+$/
				if ntok = lexer.readtok_nopp and ntok.type == :punct and ntok.raw == '.'
					# parse float
					tok.raw << ntok.raw
					ntok = lexer.readtok_nopp
					# XXX 1.0e2 => '1', '.', '0e2'
					raise tok, 'invalid float'+ntok.raw.inspect if not ntok or ntok.type != :string or ntok.raw !~ /^[0-9][0-9_e]*$/ or ntok.raw.count('e') > 1
					if ntok.raw.include? 'e'
						ntok.raw, post = ntok.raw.split('e', 2)
						if post.length > 0
							t = ntok.dup
							t.raw = post
							lexer.unreadtok t
						end
						t = ntok.dup
						t.raw = 'e'
						lexer.unreadtok t
					end
					tok.raw << ntok.raw

					if ntok = lexer.readtok_nopp and ntok.type == :string and ntok.raw == 'e'
						tok.raw << ntok.raw
						ntok = lexer.readtok_nopp
						if ntok and ntok.type == :punct and (ntok.raw == '-' or ntok.raw == '+')
							tok.raw << ntok.raw
							ntok = lexer.readtok_nopp
						end
						raise tok, 'invalid float' if not ntok or ntok.type != :string or ntok.raw !~ /^[0-9_]+$/
						tok.raw << ntok.raw
					else
						lexer.unreadtok ntok
					end
					tok.value = tok.raw.to_f
				else
					lexer.unreadtok ntok
					tok.value = tok.raw.to_i
				end
			else raise tok, 'invalid integer'
			end
		end

		# returns the next value from lexer (parenthesised expression, immediate, variable, unary operators)
		def parse_value(lexer)
			lexer.skip_space
			return if not tok = lexer.readtok
			case tok.type
			when :string
				parse_intfloat(lexer, tok)
				val = tok.value || tok.raw
			when :quoted
				if tok.raw[0] != ?'
					lexer.unreadtok tok
					return
				end
				s = tok.value || tok.raw[1..-2]	# raise tok, 'need ppcessing !'
				s = s.reverse if lexer.program and lexer.program.cpu and lexer.program.cpu.endianness == :little
				val = s.unpack('C*').inject(0) { |sum, c| (sum << 8) | c }
			when :punct
				case tok.raw
				when '('
					lexer.skip_space_eol
					val = parse(lexer)
					lexer.skip_space_eol
					raise tok, 'syntax error, no ) found' if not ntok = lexer.readtok or ntok.type != :punct or ntok.raw != ')'
				when '!', '+', '-', '~'
					lexer.skip_space_eol
					raise tok, 'need expression after unary operator' if not val = parse_value(lexer)
					val = Expression[tok.raw.to_sym, val]
				when '.'
					parse_intfloat(lexer, tok)
					if not tok.value
						lexer.unreadtok tok
						return
					end
					val = tok.value
				else
					lexer.unreadtok tok
					return
				end
			else
				lexer.unreadtok tok
				return
			end
			lexer.skip_space
			val
		end

		# for boolean operators, true is 1 (or anything != 0), false is 0
		def parse(lexer)
			opstack = []
			stack = []

			return if not e = parse_value(lexer)

			stack << e

			while op = readop(lexer)
				lexer.skip_space_eol
				until opstack.empty? or OP_PRIO[op.value][opstack.last]
					stack << new(opstack.pop, stack.pop, stack.pop)
				end
				
				opstack << op.value
				
				raise op, 'need rhs' if not e = parse_value(lexer)
				stack << e
			end

			until opstack.empty?
				stack << new(opstack.pop, stack.pop, stack.pop)
			end

			Expression[stack.first]
		end

		# same as parsing an expression, but return the array of tokens instead of the Expression
		def parse_toks(lexer)
			raise lexer.nexttok, 'invalid expression' if not p1 = parse_value_toks(lexer)
			while p2 = readop(lexer)
				p1 << p2
				while ntok = lexer.nexttok and (ntok.type == :space or ntok.type == :eol)
					p1 << lexer.readtok
				end
				p3 = parse_value_toks(lexer)
				raise p1.last, 'no right hand side expression member' if not p3
				p1.concat p3
			end
			p1
		end

		def parse_value_toks(lexer)
			ret = []
			cancel = proc { ret.reverse_each { |t| lexer.unreadtok t } ; return }
			ret << lexer.readtok while ntok = lexer.nexttok and ntok.type == :space
			cancel[] if not tok = lexer.readtok
			ret << tok
			case tok.type
			when :string
				parse_intfloat(lexer, tok)
			when :quoted
				cancel[] if tok.raw[0] != ?'
			when :punct
				case tok.raw
				when '('
					ret << lexer.readtok while ntok = lexer.nexttok and (ntok.type == :space or ntok.type == :eol)
					ret.concat parse_toks(lexer)
					ret << lexer.readtok while ntok = lexer.nexttok and (ntok.type == :space or ntok.type == :eol)
					raise tok, 'syntax error, no ) found' if not ntok = lexer.readtok or ntok.type != :punct or ntok.raw != ')'
					ret << ntok
				when '!', '+', '-', '~'
					# unary operators
					ret << lexer.readtok while ntok = lexer.nexttok and (ntok.type == :space or ntok.type == :eol)
					raise tok, 'need expression after unary operator' if not val = parse_value_toks(lexer)
					ret.concat val
				when '.'
					parse_intfloat(lexer, tok)
					cancel[] if not tok.value
				else cancel[]
				end
			else cancel[]
			end
			ret << lexer.readtok while ntok = lexer.nexttok and ntok.type == :space
			ret
		end

	end
end
end
