require 'pry'
require_relative 'Notes'
require_relative 'Note'

i = 0
note = []
all_notes = []

files = [
  '516862_NotaCorretagem1.txt',
  '516862_NotaCorretagem2.txt',
  '516862_NotaCorretagem3.txt',
  '516862_NotaCorretagem4.txt',
  '516862_NotaCorretagem5.txt',
  '516862_NotaCorretagem6.txt',
  '516862_NotaCorretagem7.txt',
  '516862_NotaCorretagem8.txt',
  '516862_NotaCorretagem9.txt',
  '516862_NotaCorretagem10.txt',
  '516862_NotaCorretagem11.txt',
  '516862_NotaCorretagem12.txt'
]

for fi in files do
  puts 'Reading file..'
  File.open(fi, 'r').each do |line|
    if line =~ /NOTA DE NEGOCIAÇÃO/
      i += 1
      puts "\t#{fi}, page #{i}"
      if i > 0
        all_notes.push(note)
        note = []
      end
    end
    note.push(line)
    # else
    # puts "Error: don't know what to do with line #{line}"
  end
  puts "\tdone"
  all_notes.push(note)
  note = []
  i = 0
end

notes = Notes.new
tr = 0
for i in 1..(all_notes.size - 1) do
  # puts all_notes[i][22]
  n = Note.new(all_notes[i])
  # puts n.inspect
  tr += n.get_trades.size
  notes.add_note(n)
end
# notes.total()
notes.tot_comuns_full
puts "Trades: #{tr}"
# binding.pry
