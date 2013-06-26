#!/usr/bin/env ruby

=begin
readWrite.rb

This simply reads an XML and writes it out again.
=end

require 'rubygems'
require 'json'
require 'trollop'
require 'rexml/document'

# include the REXML namespace so we don't have to put "REXML" infront of every function
include REXML

time = Time.new
nowStr = time.strftime("%Y%m%d-%H%M%S")

@opts = Trollop::options do
  opt :inputfile, "Input xml filename", :type=>:string, :default=>"input.xml"
  opt :outputfile, "Output xml filename", :type=>:string, :default=>"output_#{nowStr}.xml"
end
puts @opts.inspect

puts "Reading #{@opts[:inputfile]}..."
input_xml = File.new(@opts[:inputfile])
doc = Document.new(input_xml)

puts "Writing reformatted XML to #{@opts[:outputfile]}..."
File.open(@opts[:outputfile],"w") do |data|
   data << doc
end
puts "Done."
