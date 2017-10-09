#!/usr/bin/env ruby

require 'mkfifo'
require 'tempfile'

print "Hi, Jimmy. How much money do you want to put in the bank? "
amount = STDIN.readline.to_i
moneybags = "💰" *amount

puts "Wow, RubyConf must be *huge* this year!"

COMBINATION_NUMBERS = 5
COMBINATION_RANGE = 50

combination = (0..COMBINATION_RANGE).to_a.sample(COMBINATION_NUMBERS)
puts "OK the combination is #{combination.inspect}. If you ever forget it, just send a USR1 to #{$$}!"
Signal.trap('USR1') { puts combination.inspect }
Signal.trap('HUP', 'IGNORE') # So we can detach

processes = (0..COMBINATION_RANGE).to_a.each_with_object({}) do |slot_number, process_hash|
  f = Tempfile.new('bank'); p = f.path; f.close!
  pid = fork do
    Process.setproctitle("Bank pin #{slot_number}")
    puts "Write any data to #{p} to activate combination number #{slot_number}"
    Signal.trap('TERM') { File.unlink(p); exit }

    File.mkfifo(p)
    fifo = open(p, 'r+')
    loop { break if fifo.readline }
    File.unlink(p)
  end
  process_hash[pid] = slot_number
end

loop do
  begin
    pid = Process.waitpid(-1, 0)
    pressed = processes[pid]
    processes.delete(pid)

    case pressed
    when combination[0]
      puts "Correctly pressed pin #{pressed}"
      combination.shift
      if combination.empty?
        processes.keys.each { |pid| Process.kill 'TERM', pid }
        break
      end
    else
      processes.keys.each { |pid| Process.kill 'TERM', pid }
      raise("Incorrect combination number #{pressed} entered! Sorry, I am not giving you the money.")
    end
  end
end

Process.waitall

puts "You deposited #{amount} 💰 and here they are, Jimmy: #{moneybags}"
