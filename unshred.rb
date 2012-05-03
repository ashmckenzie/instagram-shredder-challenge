#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :development)

class Magick::Pixel
  def to_rgb
    [ :red, :green, :blue ].collect { |color| send(color) / 256 }
  end
end

class Unshred

  CHUNK_SIZE = 32
  OUTPUT_FILE = 'unshredded.png'

  attr_reader :img

  def initialize image
    puts "- Attempting to unshred #{image}"
    @img = Magick::Image::read(image).first
    output OUTPUT_FILE
    puts "- #{OUTPUT_FILE} should now be unshredded!"
  end

  private

  def columns
    unless @columns
      @columns = (0...(img.columns / CHUNK_SIZE)).collect do |m|
        @img.get_pixels(CHUNK_SIZE * m, 0, CHUNK_SIZE, img.rows)
      end  
    end
    @columns
  end

  def sides
    unless @sides
      @sides = columns.collect do |column|
        side = { l: [], r: [] }
        slices = column.each_slice(CHUNK_SIZE).to_a
        (0...(img.rows - 1)).each do |p|
          side[:l] << slices[p][0].to_rgb
          side[:r] << slices[p][31].to_rgb
        end
        side
      end
    end
    @sides
  end

  def slice_order
    order = {}
    already_found = []
    starting_key = -1

    sides.each_with_index do |s1, i|
      points = {}

      sides.each_with_index do |s2, j|
        next if j == i
        points[j] = diff(s1[:r], s2[:l]).flatten.inject(0) { |sum, x| x <= 15 ? sum + 1 : sum }
      end

      match_pair = points.sort_by { |x, y| y }[-1]
      index = match_pair[0] + 1
      pts = match_pair[1]

      starting_key = [ (i + 1), pts ] if starting_key == -1 || pts < starting_key[1]

      next if already_found.include?(index)

      already_found << index
      order[i + 1] = index
    end

    final_order = order.inject([ starting_key[0] ]) { |o, x| o << order[o[-1]] }
    final_order.shift
    final_order
  end

  def diff ar1, ar2
    diffs = []
    ar1.each_with_index do |x, i|
      diff = []
      x.each_with_index do |y, j|
        diff << (y - ar2[i][j]).abs
      end
      diffs << diff
    end
    diffs
  end
  
  def output file
    il = Magick::ImageList.new
    slice_order.each do |x|
      il << @img.crop((x * CHUNK_SIZE) - CHUNK_SIZE, 0, CHUNK_SIZE, @img.rows)
    end
    il.append(false).write file
  end
end

Unshred.new(ARGV[0] || 'TokyoPanoramaShredded.png')