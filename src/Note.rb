require 'pry'
require 'date'
require 'pp'

class Note

	# NUMBER = /[0-9\-.,\/]+/
	NUMBER = /[0-9\-.,]+/
	WORD = /[0-9\u00C0-\u00FFa-zA-Z\-_.,\#\/]+/
	TRADE = /[0-9\u00C0-\u00FFa-zA-Z\-_.,\#\/]+/
	# SPACE_BETWEEN_WORDS = /[0-9\u00C0-\u00FFa-zA-Z\-_.,\#\/]+( [0-9\u00C0-\u00FFa-zA-Z\-_.,\#\/]+)/
	SPACE_BETWEEN_WORDS = /[\u00C0-\u00FFa-zA-Z\-_.,\#\/]+( [\u00C0-\u00FFa-zA-Z\-_.,\#\/]+)/

	OPERS = ["D", "D#", "D#2", "8", "8#", "8D", "8D#", "8D#2", "#", "P", "H"]


	def print_resumo()
		if  @resumo.length>0 then
			Pry::ColorPrinter.pp(@resumo)
		end
	end

	def get_info()
		return @info
	end

	def get_taxas()
		return @taxas
	end

	def get_resumo()
		return @resumo
	end

	def get_tr()
		return @trades
	end

	# def get_liquido()
	# 	print "ERROR get_liquido not implemented"
	# 	exit
	# 	# liq = 0
	# 	# if (!@taxas[:liquido_para].nil?)
	# 	# 	liq = @taxas[:liquido_para]
	# 	# end
	# 	return liq
	# end

	# def get_liquido_day()
	# 	tot = 0
	# 	for t in @trades do
	# 		tot += t[:valor]
	# 	end
	# 	return tot
	# end

	def  get_id()
		return @id
	end

	def initialize( buffer )
		@trades = []

		@info = {}
		@info[:nr_nota] = 0
		@info[:folha] = 0
		@info[:data] = nil

		@resumo = {}
		@taxas = {}

		@id = ""
		@is_trade = false
		@is_future = false

		# line = buffer[0].split(/\s/)
		if buffer[0].nil? then
			return
		end

		#------------------------------------------------
		# Trade or Futures
		#------------------------------------------------
		if buffer.join.include?("Q Negocia") then
			@is_trade = true
		else
			@is_future = true
		end

		#------------------------------------------------
		# INFO
		#------------------------------------------------
		idx = 0
		found = false
		while( idx < 20 and !found) do
			# puts "line="+buffer[idx]
			if buffer[idx].include?("Nr.") and buffer[idx].include?("nota") then
				# line = buffer[1].split(/\s/)
				line = buffer[idx+1].scan(WORD)
				# puts line.inspect
				@info[:nr_nota] = line[0].gsub(".","").to_i
				@info[:folha] = line[1].to_i
				@info[:data] = Date.strptime(line[2], '%d/%m/%Y')
				@id = "#{@info[:nr_nota]} #{@info[:folha]} #{@info[:data]}"
				found = true
			end
			idx = idx + 1
		end
		if @info[:nr_nota]==0 then
			binding.pry
		end
		#------------------------------------------------
		# PROCESS
		#------------------------------------------------

		if @is_trade then
			get_resumo_trade_from( buffer )
			get_trades_from( buffer )
		end

		if @is_future then
			get_resumo_future_from( buffer )
			get_futures_from( buffer )
		end

		#------------------------------------------------
		# TRADES
		#------------------------------------------------
		#search init of trades


	end


	def get_resumo_trade_from( buffer )
		line_resumo = nil
		resumo_ok = nil
		keyw1 = "Resumo dos Neg"
		keyw2 = "CONTINUA..."
		for i in 0..(buffer.size-1) do
			if buffer[i].include?(keyw1) then
				line_resumo = i;
				resumo_ok = true
			end
			if buffer[i].include?(keyw2) then
				resumo_ok = false
			end
		end
		if line_resumo.nil? then
			puts "ERROR keyword \"#{keyw}\" not found in #{@info[:nr_nota]}-#{@info[:folha]}!"
			exit
		end

		if resumo_ok then
			@resumo[:day_debentures] 			=  parse_value(buffer, line_resumo, "Debêntures", 0)
			@resumo[:day_vendas] 	 			=  parse_value(buffer, line_resumo, "Vendas à vista", 0)
			@resumo[:day_compras]	 			=  parse_value(buffer, line_resumo, "Compras à vista", 0)
			@resumo[:day_opt_compras] 			=  parse_value(buffer, line_resumo, "Opções - compras", 0)
			@resumo[:day_opt_vendas] 			=  parse_value(buffer, line_resumo, "Opções - vendas", 0)
			@resumo[:day_op_a_termo] 			=  parse_value(buffer, line_resumo, "Operações à termo", 0)
			@resumo[:day_vlr_tot_tit] 			=  parse_value(buffer, line_resumo, "Valor das oper. c/ títulos públ. (v. nom.)", 0)
			@resumo[:day_vlr_tot] 				=  parse_value(buffer, line_resumo, "Valor das operações", 0)
			@resumo[:day_vlr_liq_op] 			=  parse_value(buffer, line_resumo, "Valor líquido das operações", 0, true)
			@resumo[:day_liquido_para]			=  parse_value(buffer, line_resumo, "Líquido para ", 3, true)
			@resumo[:day_tot_cblc]				=  parse_value(buffer, line_resumo, "Total CBLC", 0)
			@resumo[:dau_taxa_b3_soma_emolum]	=  parse_value(buffer, line_resumo, "Total Bovespa / Soma", 0)
			@resumo[:day_irrf_base]				=  parse_value(buffer, line_resumo, "I.R.R.F. s/ operações, base R$", 0)
			@resumo[:day_nr_nota]				= @info[:nr_nota]

			@taxas[:day_clearing] 				=  -parse_value(buffer, line_resumo, "Clearing", 0).abs
			@taxas[:day_taxa_liq] 				=  -parse_value(buffer, line_resumo, "Taxa de liquidação", 0).abs
			@taxas[:day_taxa_reg] 				=  -parse_value(buffer, line_resumo, "Taxa de Registro", 0).abs
			@taxas[:day_taxa_b3_termo_opt]		=  -parse_value(buffer, line_resumo, "Taxa de termo/opções", 0).abs
			@taxas[:day_taxa_b3_ana]			=  -parse_value(buffer, line_resumo, "Taxa A.N.A", 0).abs
			@taxas[:day_taxa_b3_emolum]			=  -parse_value(buffer, line_resumo, "Emolumentos", 0).abs
			@taxas[:day_taxa_custos_oper]		=  -parse_value(buffer, line_resumo, "Custos Operacionais", 0).abs
			@taxas[:day_taxa_op]				=  -parse_value(buffer, line_resumo, "Taxa Operacional", 0).abs
			@taxas[:day_taxa_exec]				=  -parse_value(buffer, line_resumo, "Execução", 0,).abs
			@taxas[:day_taxa_cutodia] 			=  -parse_value(buffer, line_resumo, "Taxa de Custódia", 0).abs
			@taxas[:day_impostos] 				=  -parse_value(buffer, line_resumo, "Impostos", 0).abs
			@taxas[:day_irrf]					=  -parse_value(buffer, line_resumo, "I.R.R.F. s/ operações, base R$", 1).abs
			@taxas[:day_outros] 				=  -parse_value(buffer, line_resumo, "Outros", 0).abs

			@resumo[:day_tot_taxas] = @taxas.map { |h| h }.map { |h| h[1] }.sum.round(2)
			@taxas[:day_nr_nota]				= @info[:nr_nota]

			if @resumo[:day_tot_taxas].nil? then
				binding.pry
			end

		end
	end

	def get_resumo_future_from( buffer )
		# puts "BUFFER ===>#{buffer}<==="
		line_resumo = nil
		resumo_ok = nil
		keyw1 = "Venda disponível"
		keyw2 = "CONTINUA..."
		for i in 0..(buffer.size-1) do
			if buffer[i].include?(keyw1) then
				line_resumo = i;
				resumo_ok = true
			end
		end
		for i in 0..(buffer.size-1) do
			if buffer[i].include?(keyw2) then
				resumo_ok = false
			end
		end
		if line_resumo.nil? then
			puts "ERROR keyword \"#{keyw1}\" not found in #{@info[:nr_nota]}-#{@info[:folha]}!"
			exit
		end

		if resumo_ok then
			res_fields = []
			res_fields[0] = ["Venda disponível",
						"Compra disponível",
						"Venda Opções",
						"Compra Opções",
						"Valor dos negócios"]
			res_fields[1] = ["IRRF",
						"IRRF Day Trade (proj.)",
						"Taxa operacional",
						"Taxa registro BM&F",
						"Taxas BM&F (emol+f.gar)"]
			res_fields[2] = ["+Outros Custos",
						"Impostos",
						"Ajuste de posição",
						"Ajuste day trade",
						"Total de custos operacionais"]
			res_fields[3] = ["Outros",
						"IRRF operacional",
						"Total Conta Investimento",
						"Total Conta Normal",
						"Total liquido (#)",
						"Total líquido da nota"]

			line = []
			for i in 0..res_fields.length-1 do
				fields = res_fields[i]
				found, line_num = get_line_num( buffer, fields)
				if !found then
					puts "ERROR keywords \"#{fields.join(" ")}\" not found in #{@info[:nr_nota]}-#{@info[:folha]}!"
					# exit
				end
				line_pos = get_pos( fields, buffer[line_num] )
				# puts "FIELD ===> #{i}"
				line[i] = split_line( line_pos, buffer[line_num+1], true)
			end
			# puts line.inspect



			@resumo[:merc_ajuste_day_trade]					= parse_f(line[2][3])
			@resumo[:merc_ajuste_de_posicao]				= parse_f(line[2][2])
			@resumo[:merc_compra_disponivel]				= parse_f(line[0][1])
			@resumo[:merc_compra_opcoes]					= parse_f(line[0][3])
			@resumo[:merc_total_conta_investimento]			= parse_f(line[3][2])
			@resumo[:merc_total_conta_normal]				= parse_f(line[3][3])
			@resumo[:merc_total_liquido_da_nota]			= parse_f(line[3][5])
			@resumo[:merc_total_liquido]					= parse_f(line[3][4])
			@resumo[:merc_valor_dos_negocio]				= parse_f(line[0][4])
			@resumo[:merc_venda_disponivel]					= parse_f(line[0][0])
			@resumo[:merc_venda_opcoes]						= parse_f(line[0][2])
			@resumo[:merc_nr_nota]							= @info[:nr_nota]
			@resumo[:merc_total_de_custos_operacionais]		= parse_f(line[2][4])

			@taxas[:merc_impostos]							= -parse_f(line[2][1])
			@taxas[:merc_irrf_day_trade]					= -parse_f(line[1][1])
			@taxas[:merc_irrf_operacional]					= -parse_f(line[3][1])
			@taxas[:merc_irrf]								= -parse_f(line[1][0])
			@taxas[:merc_outros_custos]						= -parse_f(line[2][0])
			@taxas[:merc_outros]							= -parse_f(line[3][0])
			@taxas[:merc_taxa_operacional]					= -parse_f(line[1][2])
			@taxas[:merc_taxa_registro_bmf]					= -parse_f(line[1][3])
			@taxas[:merc_taxas_bmf]							= -parse_f(line[1][4])

			@resumo[:merc_tot_taxas] = @taxas.map { |h| h }.map { |h| h[1] }.sum.round(2)
			@taxas[:merc_nr_nota]							= @info[:nr_nota]


			if @resumo[:merc_tot_taxas].nil? then
				binding.pry
			end

			puts @taxas.map { |h| h }.map { |h| h[1] }
			# if @info[:data] >= Date.new(2021,04,01) then
			# 	binding.pry
			# end

			# if @resumo[:merc_tot_taxas].nil? then
			# 	binding.pry
			# end
		end
	end

	def get_trades_from( buffer )
		l = 0
		start_trade = false
		trline = 0
		while (l < buffer.size and !start_trade)
			a_line = buffer[l].scan(WORD)
			if a_line[0] == "Q" and a_line[1]=="Negociação" then
				start_trade = true
				trline = l
				# puts "---->" + buffer[l]
			end
			l = l + 1
		end

		if (start_trade) then
			line_pos = get_pos_break_trade(buffer[trline])
			# puts  line_pos
			l = trline+1
			while buffer[l].include?("BOVESPA")
				# puts buffer[l].inspect

				# puts(buffer[l])
				the_line = format_the_line(buffer[l])
				# if @nr_nota == 1774141 then
				# 	puts buffer
				# 	exit
				# end

				# line = the_line.scan(TRADE)
				# puts "scan = " + line.inspect
				# puts the_line
				# puts line_pos.join(",")
				line = split_line(line_pos, the_line, false, true)
				# puts "split = " + line_pos.inspect
				# puts "split = " + line.inspect
				# puts(the_line)
			 	trade = nil
				if line[2] == "VISTA" or the_line =~ /FRACIONARIO/ then
					if OPERS.include?(line[5]) then
						# A - Posição futuro
						# T - Liquidação pelo Bruto    Líqui do para
						# 2 - Corretora ou pessoa vinculada atuou na contra parte.
						# C - Clubes e fundos de Ações
						# I - POP
						# # - Negócio direto
						# P - Carteira Própria
						# 8 - Liquidação Institucional
						# H - Home Broker
						# D - Day Trade
						# X - Box
						# F - Cobertura
						# Y - Desmanche de Box
						# B - Debêntures
						# L - Precatório
						trade = {
							id: 0.1, bov: line[0], cv: line[1], tipo: line[2], prazo: line[3], titulo: line[4], obs: line[5],
							qnte: format_num(line[6]),
							price: format_num(line[7]),
							valor: (line[9]=="D"?-1.0:1.0)*format_num(line[8]),
							signal: (line[9]=="D"?-1.0:1.0)
						}
					else
						# A TERMO
						trade = {
							id: 0.1, bov: line[0], cv: line[1], tipo: line[2], prazo: line[3], titulo: line[4], obs: line[5],
							qnte: format_num(line[6]),
							price: format_num(line[7]),
							valor: (line[9]=="D"?-1.0:1.0)*format_num(line[8]),
							signal: (line[9]=="D"?-1.0:1.0)
						}
							# puts trade.inspect
						# trade = [
						# 	0.2, line[0], line[1], line[2], line[3], line[4], line[5], "-",
						# 	format_num(line[6]),
						# 	format_num(line[7]),
						# 	format_num(line[8]),
						# 	line[9]
						# ]
					end
				elsif the_line =~ /OPCAO_DE_COMPRA/ then
					# binding.pry
					# puts line.inspect
					if line[4].include?("ON") or line[4].include?("PN") then
						trade = {
							id: 1.0, bov: line[0], cv: line[1], tipo: line[2], prazo: line[3], titulo: line[4], obs: line[5],
							qnte: format_num(line[6]),
							price: format_num(line[7]),
							valor: (line[9]=="D"?-1.0:1.0)*format_num(line[8]),
							signal: (line[9]=="D"?-1.0:1.0)
						}
					end
				elsif the_line =~ /OPCAO_DE_VENDA/ then
					# binding.pry
					# puts line.inspect
					if line[4].include?("ON") or line[4].include?("PN") then
						trade = {
							id: 1.1, bov: line[0], cv: line[1], tipo: line[2], prazo: line[3], titulo: line[4], obs: line[5],
							qnte: format_num(line[6]),
							price: format_num(line[7]),
							valor: (line[9]=="D"?-1.0:1.0)*format_num(line[8]),
							signal: (line[9]=="D"?-1.0:1.0)
						}
						# binding.pry
					end
				end

				trade = fix_trade(trade)
				if trade.nil? then
					puts "******** no rule for: nr_nota=#{@info[:nr_nota]})"
					puts "the_line =" + the_line.inspect
					puts "line     =" + line.inspect
					binding.pry
					exit
				else
					# puts trade.inspect
					@trades.push( trade )
				end

				# if !["C", "D"].include?( trade[trade.size-1] ) then
				# 	puts "******** ERROR during interpreting: nr_nota=#{@info[:nr_nota]})"
				# 	puts "the_line =" + the_line.inspect
				# 	puts "line     =" + line.inspect
				# 	puts "trade    =" + trade.inspect
				# 	binding.pry
				# end

				# binding.pry if @info[:nr_nota]==1640609
				l = l + 1
			end
		end
	end

	def get_futures_from( buffer )
	l = 0
	start_trade = false
	trline = 0
	while (l < buffer.size and !start_trade)
		a_line = buffer[l].scan(WORD)
		if a_line[0] == "C/V" and a_line[1]=="Mercadoria" then
			start_trade = true
			trline = l
			# puts "---->" + buffer[l]
		end
		l = l + 1
	end

	if (start_trade) then
		line_pos = get_pos_break_futures(buffer[trline])
		# puts  line_pos
		l = trline+1
		while buffer[l].include?("DAY TRADE")
			# puts buffer[l].inspect

			# puts(buffer[l])
			the_line = format_the_line(buffer[l])
			# if @nr_nota == 1774141 then
			# 	puts buffer
			# 	exit
			# end

			# line = the_line.scan(TRADE)
			# puts "scan = " + line.inspect
			# puts the_line
			# puts line_pos.join(",")
			line = split_line(line_pos, the_line)
			# puts "split = " + line_pos.inspect
			# puts "split = " + line.inspect
			# puts @info
			# puts(the_line)
			# puts line.inspect
			titulo = line[1]
			if titulo.include?("WDO") or titulo.include?("DOL") then
				tipo = "MERC_DOLAR"
			elsif titulo.include?("WIN") then
				tipo = "MERC_INDICE"
			else
				binding.pry
			end
			
			trade = {
				id: 10.1, cv:line[0], titulo: titulo,
				# line[2],
				venc: Date.strptime(line[2].gsub("@",""), '%d/%m/%Y'),
				qnte: format_num(line[3]),
				price: format_num(line[4]),
				tipo: tipo,
				valor: (line[7]=="D"?-1.0:1.0)*format_num(line[6]),
				taxa_oper: format_num(line[8]),
				signal: (line[7]=="D"?-1.0:1.0)
			}

			trade = fix_trade(trade)
			if trade.nil? then
				puts "******** no rule for: nr_nota=#{@info[:nr_nota]})"
				puts "the_line =" + the_line.inspect
				puts "line     =" + line.inspect
				binding.pry
				exit
			else
				# puts trade.inspect
				@trades.push( trade )
			end

			# puts "the_line =" + the_line.inspect
			# puts "line     =" + line.inspect
			# puts "trade    =" + trade.inspect

			# binding.pry if @info[:nr_nota]==1640609
			l = l + 1
		end
	end
end


	def fix_trade(trade)
		# fix
		trade[:titulo] = trade[:titulo].gsub("_"," ").gsub("@","").strip
		trade[:titulo_orig] = trade[:titulo]
		# enhance
		trade[:data] = @info[:data]
		trade[:folha] = @info[:folha]
		trade[:nr_nota] = @info[:nr_nota]
		#remove unused
		p1 = trade[:titulo].index(" ON")
		p2 = trade[:titulo].index(" PN")
		p3 = trade[:titulo].index(" DRN")
		p = p1||p2||p3
		trade[:titulo]=trade[:titulo][0..p&&(p+3)].strip

		# SE É NVIDIA e antes do desdobramento
		if trade[:titulo]=="NVIDIA CORP DRN" && trade[:data]<Date.new(2021,07,20) then
			trade[:qnte] = trade[:qnte]*4
			trade[:price] = trade[:qnte]/4
		end

		if trade[:tipo].nil? then
			binding.pry
		end
		return trade
	end


	def get_trades()
		return @trades
	end

	def format_num( str )
		return str.gsub(".","").gsub(",",".").to_f
	end

	def format_the_line( str )
		k = str
		safe = (str.index(" C ") or str.index(" V "))
		if safe.nil? then 
			# puts(str)
			binding.pry
		end
		pos = str.index(SPACE_BETWEEN_WORDS, safe+4)
		while !pos.nil? and pos>0
			space = str.index(/ /, pos)
			str[space] = "_"
			# search next
			pos = str.index(SPACE_BETWEEN_WORDS, safe+4)
		end
		# puts "format_the_line-> " + k + "\nto-> " + str
		return str
	end

	def get_pos_break_trade( str )
		fields = ["Q Negociação",
		"C/V Tipo mercado",
		"Prazo",
		"Especificação do título",
		"Obs. (*)",
		"Quantidade",
		"Preço / Ajuste",
		"Valor Operação / Ajuste",
		"D/C"]
		return get_pos( fields, str)
	end

	def get_pos_break_futures( str )
		fields = ["C/V",
		"Mercadoria",
		"Vencimento",
		"Quantidade",
		"Preço/Ajuste",
		"Tipo Negócio",
		"Vlr de Operação/Ajuste",
		"D/C",
		"Taxa Operacional"]
		pos = get_pos( fields, str )
		pos[1] = 8
		return pos
	end

	def get_pos (fields, str)
		pos = []
		for f in fields do
			pos.push(str.index(f))
		end
		return pos
	end


	def get_line_num (buffer, fields)

		line = nil
		field = fields.join(" ")

		found_all = false
		i = 0
		while (i< buffer.size-1) and !found_all do
			line = buffer[i].strip.gsub(/\s+/,' ')
			if !line.nil? then
				found_all = line.include?(field)
			end
			i = i + 1
		end

		return found_all, i-1
	end

	def split_line( line_pos, line, fixsignal=false, fixtrade=false)
		str = []
		# puts "LINE=>"+line.gsub(" ",".")+"<"
		for i in 0..(line_pos.size-2) do
			s = line_pos[i]
			e = line_pos[i+1]-1
			r = line[s..e]
			# puts s
			# puts e
			# puts "--> #{r} <--"
			if !r.nil? then
				r = r.strip
				r = r.gsub(/\s+/,' ') 
				# puts "--> #{r} <--"
				if !r.nil? then str.push(r) end
			end
		end
		s = line_pos[line_pos.size-1]
		e = line.size-1
		r = line[s..e]
		if r.nil? || r.empty? then
			str = str[..str.size-2]+str[str.size-1].strip.split(" ")
		else
			r = r.strip.gsub(/\s+/,' ')
			if !r.nil? then str.push(r) end
			#  puts "XXX-->" + r + "<--"
		end

		# trade fix
		if fixtrade then
			# FIX C V
			r = str
			n = r[0..0]
			str = r[1]
			s = [(str.index("C") or str.size),(str.index("V") or str.size)].min
			n.push(str[s..s])
			n.push(str[s+1..str.size].strip.gsub(/\s+/,' '))
			n = n + r[2..r.size-1]
			str = n
			# FIX LAST C D
			s = str[str.size-1].strip
			if !s.nil? && s.include?(" ") then
				str = str[..str.size-2] + str[str.size-1].strip.split(" ")
				# puts "XXX-->" + str.join(",") + "<--"
			end
		end

		if fixsignal then
			for i in 0..str.size-1 do
				if str[i].include?("|") then
					if str[i].include?("D") then
						str[i] = "-"+str[i].gsub("|","").gsub("D","").strip
					else
						str[i] = str[i].gsub("|","").gsub("C","").strip
					end
				end
			end
		end

		return str
	end

	def parse_value( buf, line_start, keyw, skip, signal=nil)
		line = nil
		for i in line_start..buf.size do
			if buf[i].include?(keyw) then
				line = buf[i]
				break
			end
		end
		# binding.pry if skip ==1
		if !line.nil? then
			pos = line.index keyw
			pos = pos + keyw.size
			line = line[pos..]
			if (!signal.nil?) and (line[line.size-2]=="D") then
				isignal = -1.0
			else
				isignal = 1.0
			end
			return isignal*(line.gsub(".","").gsub(",",".").scan(NUMBER)[skip]).to_f
		end
	end

	def parse_f( str )
		return (str.gsub(".","").gsub(",",".").scan(NUMBER)[0]).to_f.abs
	end

end
