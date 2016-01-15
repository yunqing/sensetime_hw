#!/usr/bin/env ruby
require 'optparse'
require 'singleton'
require 'pry'

def parse_argument
  options = {}
  argparser = OptionParser.new do |opts|
    opts.banner = "Usage: simplerake.rb [options] srake_file [task]"
    opts.on("-T", TrueClass, "list tasks") do |v|
      options[:list] = v
    end
    opts.on("-h", "print help") do
      puts argparser
      exit
    end
  end
  argparser.parse!
  mandatory = []
  missing = mandatory.select{ |param| options[param].nil? }
  unless missing.empty?
    puts "Missing options: #{missing.join(', ')}"
    puts argparser
    exit
  end
  return options
end

class Task
  attr_accessor :name, :prereq, :description, :block, :is_done

  def initialize(tsk, &block)
    @prereq = []
    @description = Description.new("")
    @is_done = false
    if tsk.is_a?(Hash)
      @name = tsk.keys[0]
      if tsk.values[0].is_a?(Symbol)
        @prereq << tsk.values[0]
      elsif tsk.values[0].is_a?(Array)
        tsk.values[0].each  {|x| @prereq << x}
      end
    elsif tsk.is_a?(Symbol)
      @name = tsk
    end
  end

  def add_description(desc)
    if desc.is_a?(String)
      @description = Description.new(desc)
    else
      @description = desc
    end
  end

  def add_block(block)
    @block = block
  end
end

class Description
  attr_accessor :text

  def initialize(text)
    @text = text
  end
end

class SimpleRake
  include Singleton

  def initialize()
    @tasks = {}
    @last_description = Description.new("")
  end

  def add_description(desc)
    @last_description = desc
  end

  def add_task(tsk)
    tsk.add_description(@last_description)
    @last_description = Description.new("")
    @tasks[tsk.name] = tsk
  end

  def get_all_prereq
    @tasks.each do |k, v|
      p "name, prereq: ", v.name, v.prereq
    end
  end

  def get_description
    @tasks.each do |k, v|
      unless k == :default
        puts "#{k}\t\t# #{v.description.text}"
      end
    end
  end

  def run_task(tsk)
    if @tasks.has_key?(tsk)
      @tasks[tsk].prereq.each {|x| run_task(x)}
      if (@tasks[tsk].prereq.map {|x| @tasks.has_key?(x)}).any? {|x| x == false}
        puts "#{tsk} was not executed due to undone prerequisite tasks."
      else 
        @tasks[tsk].block.call unless tsk == :default || @tasks[tsk].is_done == true
        @tasks[tsk].is_done = true
      end
    else
      puts "#{tsk} not defined."
    end
  end
end

def sh(cmd)
  print `#{cmd}`
end

def task(tsk)
  t = Task.new(tsk)
  if block_given?
    block = Proc.new
    t.add_block(block)
  end
    SimpleRake.instance.add_task t
end

def desc(x)
  SimpleRake.instance.add_description Description.new(x)
end

opt = parse_argument
if_list_tasks = opt[:list]
srake_file, task_to_do = ARGV
unless srake_file == nil
  load srake_file
end
if if_list_tasks
  SimpleRake.instance.get_description
  exit
end
task_to_do.nil? ? SimpleRake.instance.run_task(:default) : SimpleRake.instance.run_task(task_to_do.to_sym)
