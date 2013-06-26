#!/usr/bin/env ruby

=begin
timecodeSync.rb

This Ruby script synchronizes movie tracks by automatically synchronizing video and audio
tracks base don SMPTE timecode in a XML interchange format Apple Final Cut Pro v7 or Adobe
Premiere Pro v6 and up.

This does it by editing the <start> value of each track.
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

puts "NOTE: The sequence timecode must equal or precede the track timecode(s)"

puts "Reading input XML #{@opts[:inputfile]}..."

input_xml = File.new(@opts[:inputfile])
doc = Document.new(input_xml)

class Timecode
  attr_accessor :hh, :mm, :ss, :ff, :fps
  # hh = hour (00-23)
  # mm = minute (00-59)
  # ss = second (00-59)
  # ff = frame (00-[fps-1]) -- e.g., 00-23 for a 24 fps video
  # fps = frames per second -- I assume that the fps has to be a 2 digits number 10-99

  def initialize(timecodeString, fps) # timecode string should be in the format HH:MM:SS:FF
    regexp = /(\d{2}):(\d{2}):(\d{2}):(\d{2})/
    # right now I assum that the fps must be a 2 digits number

    match = timecodeString.match regexp
    @hh = match[1].to_i
    @mm = match[2].to_i
    @ss = match[3].to_i
    @ff = match[4].to_i
    @fps = fps
  end

  def string
    "#{format('%02d',@hh)}:#{format('%02d',@mm)}:#{format('%02d',@ss)}:#{format('%02d',@ff)}"
  end

  def frame
    (@ff + (@ss + @mm*60 + @hh*3600) * @fps)
    # This translate the timecode of sequence to a frame number where frame 0 = 00:00:00:00
  end
end
#y = Adder.new(12)
#puts y.my_num  # => 12

# Iterate through XML sequences -- I presume there is only one sequence, but that is not
# necessary for this to work

puts "Adjusting video and audio tracks to start in the right frame per this equation:"
puts "   track starting frame = (track timecode - sequence timecode) / frames per second"

doc.elements.each("*/sequence") do |sequence|
  # Get the master time code of the Sequence
  seqName = sequence.elements().to_a('name').first.text
  sequence_fps = sequence.elements().to_a('timecode/rate/timebase').first.text.to_i
  seqTimecodeStr = sequence.elements().to_a('timecode/string').first.text
  seqTimecode = Timecode.new(seqTimecodeStr, sequence_fps)
  puts "--------------------"
  puts "Sequence name: #{seqName}"
  puts "Sequence timecode: #{seqTimecode.string}"
  puts "Sequence starting frame: #{seqTimecode.frame}"

  startTimes = Hash.new
  savedTracks = Array.new

  puts "\n"
  puts "Iterating through tracks..."

  doc.elements.each("*/sequence/media/*/track") do |track|

    if track.elements().to_a('clipitem/name').first.nil? == false
      trkName = track.elements().to_a('clipitem/name').first.text

      puts "Track name: #{trkName}" 
      
      startFrame = track.elements().to_a('clipitem/start').first.text.to_i
      endFrame = track.elements().to_a('clipitem/end').first.text.to_i
      duration = endFrame - startFrame
      
      begin
        trkTimecodeStr = track.elements().to_a('clipitem/file/timecode/string').first.text
        trkTimecode = Timecode.new(trkTimecodeStr, sequence_fps)
        newStart = trkTimecode.frame - seqTimecode.frame
      rescue
        # there is no master timecode for this track
        # try to get the start time from a previous track with the same name
        newStart = startTimes[trkName]
      end
      
#      if newStart.nil? == false
        newEnd = newStart + duration
      
        track.elements().to_a('clipitem/start').first.text = newStart
        track.elements().to_a('clipitem/end').first.text = newEnd
        
        puts "  start : #{startFrame} --> #{newStart}" 
        puts "  end   : #{endFrame} --> #{newEnd}"
        puts "  length: #{duration} --> #{newEnd-newStart}"
#      else
#        puts "  Couldn't find a start time for #{trkName}: will rerun at end."
#        savedTracks.push(track)
#      end

      startTimes[trkName] = newStart
    else
      # it's possible that this track doesn't have a name and isn't a real track --
      # if so, we don't do anything in the else block, which skips this track
    end
  end
end

# DONE PARSING AND UPDATING START TIME, WRITE TO OUTPUT FILE

puts "\n"
puts "Writing adjusted XML to #{@opts[:outputfile]}..."
File.open(@opts[:outputfile],"w") do |data|
   data << doc
end
puts "Done."
