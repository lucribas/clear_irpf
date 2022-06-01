require 'pp'

class Notes
  def initialize
    @print_h = false
    @tot_liq = 0
    @tot_liq_day = 0
    @tot_liq_term = 0
    @all_notes = {}
    @resultado = {}
    @p_header = false
  end

  def print_header
    @print_h = true
    puts "nota  \tpgs   \tdate        \ttot_liq   \ttot_liq_day"
  end

  def add_note(a_note)
    info = a_note.get_info
    if info[:nr_nota] == 0
      puts 'EMPTY note:'
      Pry::ColorPrinter.pp(a_note)
      return
    end
    @all_notes[info[:nr_nota]] = [] if @all_notes[info[:nr_nota]].nil?
    @all_notes[info[:nr_nota]].push(a_note)
    puts "#{info[:nr_nota]}: #{info[:folha]}"
  end

  def tot_comuns_full
    carteira = {}
    taxas = {}
    resumo = {}

    Pry::ColorPrinter.pp(@all_notes.keys)
    for k_note in @all_notes.keys do
      pages = @all_notes[k_note]

      for note in pages do
        info = note.get_info

        the_taxas = note.get_taxas
        if the_taxas.length > 0
          taxas[info[:data]] = [] if taxas[info[:data]].nil?
          taxas[info[:data]].push(the_taxas)
        end

        the_resumo = note.get_resumo
        if the_resumo.length > 0
          resumo[info[:data]] = [] if resumo[info[:data]].nil?
          resumo[info[:data]].push(the_resumo)
        end

        tr = note.get_tr

        puts puts

        for t in tr do
          # push carteira
          carteira[t[:titulo]] = {} if carteira[t[:titulo]].nil?
          carteira[t[:titulo]][t[:data]] = [] if carteira[t[:titulo]][t[:data]].nil?
          carteira[t[:titulo]][t[:data]].push(t)
        end
      end
    end
    Pry::ColorPrinter.pp carteira.keys.sort

    # DAYTRADE

    daytrade = {}
    termo = {}
    tot_lucro_day = 0

    for tit in carteira.keys.sort do
      tot_qnte = 0

      for dia in carteira[tit].keys.sort do
        if dia >= Date.new(2022, 1, 1) or dia < Date.new(2021, 1, 1)
          puts "SKIP DIA #{dia}"
          next
        end
        # tot day trade
        day_qnte = 0
        qnte_c = 0
        qnte_v = 0
        valor_c = 0
        valor_v = 0
        for tr in carteira[tit][dia] do
          tipo = tr[:tipo]
          is_c = tr[:cv] == 'C'
          qnte_c += is_c ? tr[:qnte] : 0
          valor_c += is_c ? (-tr[:valor]) : 0

          is_v = tr[:cv] == 'V'
          qnte_v += is_v ? tr[:qnte] : 0
          valor_v += is_v ? tr[:valor] : 0

          qnte = is_v ? tr[:qnte] : (-tr[:qnte])
          day_qnte += qnte
          tot_qnte += qnte
        end
        puts "#{dia}  #{tit}  [#{qnte}  #{day_qnte}]  #{tot_qnte} "
        qnte_day = [qnte_c, qnte_v].min
        qnte_comuns = qnte_v - qnte_c
        if qnte_comuns != day_qnte
          puts 'ERROR'
          binding.pry
        end
        if qnte_day > 0
          medio_c = valor_c / qnte_c
          medio_v = valor_v / qnte_v
          lucro_day = qnte_day * medio_v - qnte_day * medio_c
          puts "\t day_trade:  qnte_day=#{qnte_day.round(0)} qnte_c=#{qnte_c.round(0)} qnte_v=#{qnte_v.round(0)}  lucro_day=#{lucro_day.round(2)}"
          tot_lucro_day += lucro_day

          # if (resumo[dia].last[:vlr_liq_op].round(2) == lucro_day.round(2)) then
          # 	puts "VLR_LIQ_OP OK"
          # else
          # 	binding.pry
          # end

          # TODO:
          # criar um hash para o report do resultado do daytrade
          # depois é so imprimir por mes, dia
          # nao esquecer de considerar as taxas
          daytrade[dia] = [] if daytrade[dia].nil?
          daytrade[dia].push({
                               dia: dia,
                               tit: tit,
                               valor_c: valor_c,
                               valor_v: valor_v,
                               qnte_day: qnte_day,
                               lucro_day: lucro_day.round(2)
                             })
          # binding.pry
          reg_resultado(dia, { tipo: tr[:tipo], day: lucro_day, termo: 0 })

          #  binding.pry
        end
        next unless qnte_comuns != 0

        valor_comuns = if qnte_v > qnte_c
                         qnte_comuns * valor_v / qnte_v
                       else
                         qnte_comuns * valor_c / qnte_c
                       end
        # valor_comuns = valor_v-valor_c
        medio_comuns = valor_comuns / qnte_comuns
        puts "\t a_comuns:   valor_comuns=#{valor_comuns.round(2)} qnte_comuns=#{qnte_comuns.round(0)} medio_comuns=#{medio_comuns.round(4)}"
        # binding.pry
        # TODO:
        # criar um hash para receber os termos: data, titulo, valor_comuns, qnte_comuns, medio_comuns
        # ai eu consigo totalizar eles e gerar o report termo
        # nao esquecer de considerar as taxas
        termo[dia] = [] if termo[dia].nil?
        is_c = (valor_comuns) > 0
        termo[dia].push({
                          dia: dia,
                          tit: tit,
                          tipo: tipo,
                          cv: is_c ? 'V' : 'C',
                          valor_c: is_c ? 0 : valor_comuns.abs,
                          qnte_c: is_c ? 0 : qnte_comuns.abs,
                          valor_v: is_c ? valor_comuns.abs : 0,
                          qnte_v: is_c ? qnte_comuns.abs : 0,
                          # valor_comuns: valor_comuns,
                          # qnte_comuns: qnte_comuns,
                          medio_comuns: medio_comuns
                        })
      end
    end

    tot_lucro_comuns = 0
    puts '--------------------------------------------'
    puts ' A TERMO'
    puts '--------------------------------------------'
    puts 'saldo inicial:'
    puts 'ZERO'
    saldo = {}
    year = 2021
    d = Date.new(year, 1, 1).prev_month
    for m in 1..20 do
      d = d.next_month
      puts "#{d.strftime('%m/%d/%Y')} : "
      keys = termo.keys.select { |k| k >= d && k < d.next_month }.sort
      puts '   trades:'
      balance = {}
      @p_header = true
      for k in keys do
        for t in termo[k] do
          # puts "\t#{t}"
          print_trade t
          balance[t[:tit]] = [] if balance[t[:tit]].nil?
          balance[t[:tit]].push(t)
        end
      end
      for k in balance.keys.sort do
        b = balance[k]
        tipo = nil
        for i in b do
          # print_trade i
          puts i
          tipo = i[:tipo]
          binding.pry if tipo.nil?
        end
        sum_valor_c = b.map { |k| k[:valor_c] }.sum
        sum_valor_v = b.map { |k| k[:valor_v] }.sum
        sum_qnte_c = b.map { |k| k[:qnte_c] }.sum
        sum_qnte_v = b.map { |k| k[:qnte_v] }.sum
        puts "\t termo:  sum_qnte_c=#{sum_qnte_c.round(0)} sum_qnte_v=#{sum_qnte_v.round(0)}"

        qnte_comuns = sum_qnte_v - sum_qnte_c
        qnte_day = [sum_qnte_c, sum_qnte_v].min
        if qnte_day > 0
          medio_c = sum_valor_c / sum_qnte_c
          medio_v = sum_valor_v / sum_qnte_v
          lucro_day = qnte_day * medio_v - qnte_day * medio_c
          puts "\t termo:  qnte_neg=#{qnte_day.round(0)} medio_c=#{medio_c.round(4)} medio_v=#{medio_v.round(4)} lucro_comuns=#{lucro_day.round(2)}"
          tot_lucro_comuns += lucro_day
          reg_resultado(b.map { |k| k[:dia] }.max, { tipo: tipo, day: 0, termo: lucro_day })
        end

        next unless qnte_comuns.abs > 0

        medio_comuns = qnte_comuns > 0 ? (sum_valor_v / sum_qnte_v) : (sum_valor_c / sum_qnte_c)
        valor_comuns = qnte_comuns * medio_comuns

        puts "\t termo:  qnte_saldo=#{qnte_comuns.round(0)} medio_comuns=#{medio_comuns.round(4)} valor_comuns=#{valor_comuns.round(2)}"

        termo[d.next_month] = [] if termo[d.next_month].nil?
        # binding.pry
        # termo[d.next_month].push( { qnte_comuns: qnte_comuns, medio_comuns: medio_comuns, valor_comuns: valor_comuns})
        is_c = qnte_comuns > 0
        termo[d.next_month].push(
          {
            dia: d.next_month,
            tit: k,
            tipo: tipo,
            cv: is_c ? 'V' : 'C',
            valor_c: is_c ? 0 : valor_comuns.abs,
            qnte_c: is_c ? 0 : qnte_comuns.abs,
            valor_v: is_c ? valor_comuns.abs : 0,
            qnte_v: is_c ? qnte_comuns.abs : 0,
            medio_comuns: medio_comuns,
            desc: 'previous_month'
          }
        )

      end

    end

    puts "\t TOTAIS"
    puts "\t day_trade:		  tot_lucro_day=#{tot_lucro_day.round(2)}"
    puts "\t termo:  		tot_lucro_comuns=#{tot_lucro_comuns.round(2)}"

    puts '--------------------------------------------'
    puts ' RESUMOS MES A MES'
    puts '--------------------------------------------'
    puts 'saldo inicial:'
    saldo = {}
    year = 2021
    d = Date.new(year, 1, 1).prev_month
    fields = []
    prepare = []
    for m in 1..20 do
      d = d.next_month
      keys = @resultado.keys.select { |k| k >= d && k < d.next_month }.sort
      for k in keys do
        for r in resumo[k] do
          # binding.pry
          mrg = { dia: d, dia_nota: k }.merge(r)
          for f in mrg.keys do
            fields.push f unless fields.include?(f)
          end
          prepare.push mrg
        end
        for r in taxas[k] do
          # binding.pry
          mrg = { dia: d, dia_nota: k }.merge(r)
          for f in mrg.keys do
            fields.push f unless fields.include?(f)
          end
          prepare.push mrg
        end
      end
    end
    @p_header = true
    # binding.pry
    for m in prepare do
      print_resumo fields, m
    end

    puts '--------------------------------------------'
    puts ' RESULTADOS MES A MES'
    puts '--------------------------------------------'
    puts 'saldo inicial:'
    saldo = {}
    year = 2021
    d = Date.new(year, 1, 1).prev_month
    puts 'date,result_comuns,result_daytrade,taxas'
    for m in 1..20 do
      d = d.next_month
      keys = @resultado.keys.select { |k| k >= d && k < d.next_month }.sort

      tot_comuns = 0
      tot_day = 0
      tot_taxas = 0

      for k in keys do
        tot_comuns += @resultado[k].map { |r| r[:termo] }.sum
        tot_day += @resultado[k].map { |r| r[:day] }.sum

        tot_taxas += -resumo[k].map  do |r|
          day = r[:day_tot_taxas]
          day = day.nil? ? 0 : day.abs
          merc = r[:merc_tot_taxas]
          merc = merc.nil? ? 0 : merc.abs
          day + merc
        end.sum

      end
      puts "#{d.strftime('%d/%m/%Y')},#{tot_comuns.round(2)},#{tot_day.round(2)},#{tot_taxas.round(2)}"
    end

    puts '--------------------------------------------'
    puts ' RESULTADOS MES A MES - EXTRATIFICADO'
    puts '--------------------------------------------'
    puts 'saldo inicial:'
    saldo = {}
    year = 2021
    d = Date.new(year, 1, 1).prev_month
    puts 'date,tot_comuns_acoes,tot_day_acoes,tot_comuns_opcoes,tot_day_opcoes,tot_comuns_dolar,tot_day_dolar,tot_comuns_indice,tot_day_indice,taxas,tot_ir_comuns,tot_ir_day'
    for m in 1..20 do
      d = d.next_month
      keys = @resultado.keys.select { |k| k >= d && k < d.next_month }.sort

      tot_comuns_acoes = 0
      tot_comuns_opcoes = 0
      tot_comuns_dolar = 0
      tot_comuns_indice = 0
      tot_day_acoes = 0
      tot_day_opcoes = 0
      tot_day_dolar = 0
      tot_day_indice = 0
      tot_ir_comuns = 0
      tot_ir_day = 0
      tot_taxas = 0

      for k in keys do

        # puts @resultado[k]
        # binding.pry

        for r in @resultado[k] do
          is_op	= r[:tipo].include?('OPCAO')
          is_dolar	= r[:tipo].include?('MERC_DOLAR')
          is_indice	= r[:tipo].include?('MERC_INDICE')
          is_comum	= !(is_op || is_dolar || is_indice)

          tot_comuns_acoes	+= is_comum ? r[:termo] : 0
          tot_day_acoes	+= is_comum ? r[:day] : 0
          tot_comuns_opcoes	+= is_op ? r[:termo] : 0
          tot_day_opcoes	+= is_op ? r[:day] : 0
          tot_comuns_dolar	+= is_dolar ? r[:termo] : 0
          tot_day_dolar	+= is_dolar ? r[:day] : 0
          tot_comuns_indice	+= is_indice ? r[:termo] : 0
          tot_day_indice	+= is_indice ? r[:day] : 0
        end
        tot_ir_comuns += -taxas[k].map do |r|
          i = r[:day_irrf]
          i.nil? ? 0 : i.abs
        end.sum

        tot_ir_day += -taxas[k].map do |r|
          i = r[:merc_irrf_day_trade]
          i.nil? ? 0 : i.abs
        end.sum

        tot_taxas += -resumo[k].map do |r|
          day = r[:day_tot_taxas]
          day = day.nil? ? 0 : day.abs
          merc = r[:merc_tot_taxas]
          merc = merc.nil? ? 0 : merc.abs
          day + merc
        end.sum

      end
      puts("#{d.strftime('%d/%m/%Y')}," +
        "#{tot_comuns_acoes.round(2)}," +
        "#{tot_day_acoes.round(2)}," +
        "#{tot_comuns_opcoes.round(2)}," +
        "#{tot_day_opcoes.round(2)}," +
        "#{tot_comuns_dolar.round(2)}," +
        "#{tot_day_dolar.round(2)}," +
        "#{tot_comuns_indice.round(2)}," +
        "#{tot_day_indice.round(2)}," +
        "#{tot_taxas.round(2)}," +
        "#{tot_ir_comuns.round(2)}," +
        "#{tot_ir_day.round(2)}")
    end

    binding.pry
  end

  def check_notes
    a_note.print_resumo
    # pp a_note
    # puts "total liq note= #{@resumo[:vlr_liq_op].round(2)}"
    # if @resumo.nil? or @resumo[:vlr_liq_op].nil? or !(tot.round(2) == @resumo[:vlr_liq_op].round(2) ) then
    # 	puts "ERROR - TOTAL NOTA DIFERENTE SOMA TRADES:"
    # 	for i in 0..@trades.size-1 do
    # 		puts @trades[i].inspect
    # 	end
    # 	Pry::ColorPrinter.pp(@resumo)
    # end
  end

  def reg_resultado(d, r)
    if @resultado[d].nil?
      @resultado[d] = [r]
    else
      @resultado[d].push(r)
    end
  end

  def print_trade(t)
    binding.pry if t.keys.nil?
    if @p_header
      puts t.keys.join(',')
      @p_header = false
    end
    # binding.pry
    puts "#{t[:dia].strftime('%m/%d/%Y')},#{t.values[1..].join(',')}"
  end

  def print_resumo(f, m)
    if @p_header
      puts f.join(',')
      @p_header = false
    end
    t = {}
    for k in f do
      s = m[k]
      s = s.nil? ? 0 : s
      if t[k].nil?
        t = t.merge({ k => s })
      # binding.pry
      else
        puts "ERROR duplicate name: #{k}"
        binding.pry
      end
      # binding.pry
    end
    puts "#{t[:dia].strftime('%m/%d/%Y')},#{t[:dia_nota].strftime('%m/%d/%Y')},#{t.values[2..].join(',')}"
    # puts t[:nr_nota]
    # if t[:nr_nota].nil? or t[:nr_nota]=="" or t[:nr_nota]==0 then
    # 	puts t[:nr_nota]
    # 	binding.pry
    # end
  end
end
