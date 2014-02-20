require 'awesome_print'

class Printer
  attr_accessor :axes 
  attr_accessor :last_command

  def initialize args=nil
    @axes = Hash.new
  end

  def run_command command
    # we don't want to remember these axes from command to command
    @axes[:e] = nil
    @axes[:f] = nil

    command.axes.each do |k,v|
      key = k.downcase.to_sym
      @axes[key] = v
    end

    @last_command = command
  end
end

class DeltaPrinter < Printer
  # DELTA_SEGMENTS_PER_SECOND = 120
  DELTA_DIAGONAL_ROD = 213.0
  DELTA_SMOOTH_ROD_OFFSET = 146.5
  DELTA_EFFECTOR_OFFSET = 19.9
  DELTA_CARRIAGE_OFFSET = 19.5
  DELTA_RADIUS = ( DELTA_SMOOTH_ROD_OFFSET-DELTA_EFFECTOR_OFFSET-DELTA_CARRIAGE_OFFSET )
  DELTA_Z_OFFSET = Math.sqrt( DELTA_DIAGONAL_ROD ** 2 - DELTA_RADIUS ** 2 ).round 2

  SIN_60 = 0.8660254037844386
  COS_60 = 0.5
  DELTA_TOWER1_X = -SIN_60*DELTA_RADIUS # front left tower
  DELTA_TOWER1_Y = -COS_60*DELTA_RADIUS
  DELTA_TOWER2_X = SIN_60*DELTA_RADIUS # front right tower
  DELTA_TOWER2_Y = -COS_60*DELTA_RADIUS
  DELTA_TOWER3_X = 0.0 # back middle tower
  DELTA_TOWER3_Y = DELTA_RADIUS
  DELTA_DIAGONAL_ROD_2 = DELTA_DIAGONAL_ROD ** 2
end

class Command
  def self.from_gcode line
    line = strip_comments line
    tokens = line.split /\s+/
    command = tokens.first
    return { command: command, params: tokens[1..-1] }
  end

  def self.strip_comments line
    line.split(";").first
  end

end

class GCommand < Command
  attr_accessor :axes
  attr_accessor :command

  def initialize command, axes=nil
    @command = command
    @axes = axes
  end

  def self.from_gcode line
    line = super
    raise "WHAT ARE YOU DOING" if line[:command] != "G1"

    axes = {}
    line[:params].each do |param|
      raise "INVALID G1 PARAMETER: #{param}" if param !~ /^[XYZEF]/
      axis = param[0]
      value = param[1..-1]
      axes[axis.downcase.to_sym] = value.to_f
    end

    return GCommand.new line[:command], axes
  end

  def to_gcode
    parameters = @axes.map { |k, v| "#{k.to_s.upcase}#{v.round(4)}" }
    "#{@command.upcase} #{parameters.join(' ')}"
  end
end

class CommandCollection
  attr_reader :values

  def initialize array
    @values = array
  end

  def to_gcode
    @values.map( &:to_gcode ).join "\n"
  end
end

class DeltaConverter
  attr_accessor :cartisian
  attr_accessor :delta

  def initialize infile
    @cartisian = Printer.new
    @delta = DeltaPrinter.new

    gcode_lines = infile.readlines
    gcode_lines.each do |line|
      if line !~ /^G1/
        puts line
        next
      end

      # parse the command from the gcode
      command = GCommand.from_gcode line

      puts @delta.run_command( to_delta( command ) ).to_gcode + " ; -- delta"
      @cartisian.run_command( command ).to_gcode + " ; -- cartisian" # this is done so we can get the current state of the cartisian printer for the next command
      # puts ""
    end
  end

  def to_delta command
    # convert command to delta do pythagoris...
    newcommand = GCommand.new command.command, command.axes.clone

    # assuming z is not combined with another axis in a G1 command
    # if newcommand.axes[:z]
    #   newcommand = convert_z_movement newcommand
    # else
    newcommand = convert_xy_movement newcommand
    # end

    newcommand
  end

  def convert_xy_movement command
    x = command.axes[:x].to_f
    y = command.axes[:y].to_f
    z = command.axes[:z].to_f
    x = @cartisian.axes[:x].to_f if x.nil?
    y = @cartisian.axes[:y].to_f if y.nil?
    z = @cartisian.axes[:z].to_f if z.nil?
    newx = Math.sqrt( DeltaPrinter::DELTA_DIAGONAL_ROD_2 - (DeltaPrinter::DELTA_TOWER1_X - x) ** 2 - (DeltaPrinter::DELTA_TOWER1_Y - y) ** 2 ) + z
    newy = Math.sqrt( DeltaPrinter::DELTA_DIAGONAL_ROD_2 - (DeltaPrinter::DELTA_TOWER2_X - x) ** 2 - (DeltaPrinter::DELTA_TOWER2_Y - y) ** 2 ) + z
    newz = Math.sqrt( DeltaPrinter::DELTA_DIAGONAL_ROD_2 - (DeltaPrinter::DELTA_TOWER3_X - x) ** 2 - (DeltaPrinter::DELTA_TOWER3_Y - y) ** 2 ) + z
    command.axes[:x] = x + DeltaPrinter::DELTA_Z_OFFSET
    command.axes[:y] = y + DeltaPrinter::DELTA_Z_OFFSET
    command.axes[:z] = z + DeltaPrinter::DELTA_Z_OFFSET
    return command
  end

  # def convert_z_movement newcommand
  #   diff = newcommand.axes[:z] - @cartisian.axes[:z].to_f

  #   if @cartisian.axes[:z].nil?
  #     newcommand.axes[:x] = newcommand.axes[:y] = newcommand.axes[:z] = DeltaPrinter::DELTA_Z_OFFSET + diff
  #   else
  #     newcommand.axes[:x] = c[:x] + diff
  #     newcommand.axes[:y] = c[:y] + diff
  #     newcommand.axes[:z] = c[:z] + diff
  #   end

  #   newcommand
  # end
end

DeltaConverter.new $stdin if __FILE__ == $0
