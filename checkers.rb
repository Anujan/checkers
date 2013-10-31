require "colorize"
class Piece
  attr_accessor :pos, :color, :king, :board
  DIAGS = {
    :black => [[1,1], [1, -1]],
    :white => [[-1, 1], [-1, -1]]
  }

  def initialize(pos, color, board, king=false)
    @board = board
    @pos = pos
    @king = king
    @color = color
  end

  def kinged?
    @king
  end

  def diagonals
    #REV: elegant one-liner.. nice
    self.kinged? ? DIAGS[:black].concat(DIAGS[:white]) : DIAGS[color]
  end

  def slide_moves
    self.diagonals.map do |diag|
      to_move = [diag[0] + self.pos[0], diag[1] + self.pos[1]]
      next if self.board.off_the_grid?(to_move) || !self.board[to_move].nil?
      to_move
    end.compact
  end

  def jump_moves
    moves = []
    jump_diags = self.diagonals.map do |p|
      p.map.with_index do |el, i|
        pos[i] + (el * 2)
      end
    end
    self.diagonals.each_with_index do |diag, idx|
      diag_pos = diag.map.with_index { |el, i| pos[i] + el }
      next if self.board.off_the_grid?(jump_diags[idx]) || self.board[diag_pos].nil? || !self.board[jump_diags[idx]].nil? || self.board[diag_pos].color == self.color
      moves << jump_diags[idx]
    end

    moves
  end

  def moves
    #REV: so this is the strict version where you have to jump if you can?
    jumps = jump_moves
    jumps.empty? ? slide_moves : jump_moves
  end

  def pos=(value)
    @board.remove_piece(self.pos)
    @pos = value
    @board.add_piece(self)

    king_row = color == :white ? 0 : 7
    if pos.first = king_row
      @king = true
    end
  end

  def symbol
    if (color == :white)
      self.kinged? ? "\u263A" : "\u25CB"
    else
      self.kinged? ? "\u263B" : "\u25CF"
    end
  end
end

class InvalidMoveError < StandardError
end

class Board
  attr_accessor :pieces
  def initialize(pieces=nil)
    if pieces.nil?
      @pieces = Array.new(8) { Array.new(8) }
      build_board
    else
      @pieces = pieces
    end
  end

  def add_piece(piece)
    self[piece.pos] = piece
  end

  def remove_piece(pos)
    self[pos] = nil
  end

  def [](pos)
    pieces[pos[0]][pos[1]]
  end

  def render
    colored = true
    render = "      "
    (0..7).each { |x| render += "  #{x.to_s}  ".rjust(5) }
    render += "\n"
    pieces.each_with_index do |row, ri|
      ri = " " if ri.zero?
      render += ri.to_s.rjust(5)
      row.each do |piece|
        symbol = (piece.nil? ? "     " : "  #{piece.symbol}  ").rjust(5)
        bg = colored ? :default : :green
        color =   piece.nil? ? :default : piece.color
        render += symbol.colorize(background: bg, color: color)
        colored = !colored
      end
      colored = !colored
      render += "\n"
    end

    render
  end

  def off_the_grid?(pos)
    pos.each { |z| return true unless (0..7).include?(z)}

    false
  end

  def all_pieces(&prc)
    #REV: elegant versatile method!
    prc = Proc.new { true } unless
    prc.nil?
    pieces.flatten.compact.select(&prc)
  end

  def perform_moves(sequence, color)
    #REV: did you make sure to not allow a player to slide after jumping?
    #REV: if so it's unclear to me
    result = valid_move_seq?(sequence, color)
    unless result[:success]
      raise InvalidMoveError, result[:message]
    end
    self.perform_moves!(sequence, color)
  end

  protected
    def []=(pos, val)
      pieces[pos[0]][pos[1]] = val
    end

    def perform_slide(piece, end_pos)
      raise InvalidMoveError, "That piece can't move there" unless piece.slide_moves.include?(end_pos)
      piece.pos = end_pos
    end

    def perform_jump(piece, end_pos)
      piece_between = piece.pos.map.with_index do |el, i|
        el + ((end_pos[i] - piece.pos[i]) / 2)
      end
      raise InvalidMoveError, "No piece to jump at #{piece_between}" if self[piece_between].nil?
      remove_piece(piece_between)
      piece.pos = end_pos
    end

    def jumper_pieces(color)
      all_pieces.select { |piece| !piece.jump_moves.empty? }
    end

    def perform_moves!(sequence, color)
      start_pos = sequence.shift
      piece = self[start_pos]
      raise InvalidMoveError, "No piece at #{start_pos}" if piece.nil?
      raise InvalidMoveError, "You can only move your own pieces" if piece.color != color
      if is_jump_move?(piece, sequence)
        jump_move(piece, sequence)
      else
        slide_move(piece, sequence)
      end
    end

    def slide_move(piece, sequence)
      raise InvalidMoveError, "You have a piece that's able to jump, so you have to jump." unless jumper_pieces(color).empty?
      perform_slide(piece, sequence.first)
    end

    def jump_move(piece, sequence)
      raise InvalidMoveError, "This piece can't jump there..." unless piece.jump_moves.include?(sequence.first)
      until sequence.empty?
        perform_jump(piece, sequence.shift)
      end
      raise InvalidMoveError, "Jumping is mandatory if you're able to" unless piece.jump_moves.empty?
    end

    def valid_move_seq?(sequence, color)
      begin
        new_board = self.dup
        new_board.perform_moves!(sequence.deep_dup, color)
      rescue InvalidMoveError => e
        {success: false, message: e.message}
      else
        {success: true}
      end
    end

    def dup
      new_pieces = Array.new(8) { Array.new(8) }
      new_board = Board.new(new_pieces)
      self.pieces.flatten.compact.each do |piece|
        new_board.add_piece(Piece.new(piece.pos, piece.color, new_board, piece.kinged?))
      end

      new_board
    end

    def build_board
      rows = (0..2).to_a + (5..7).to_a
      rows.each do |row|
        8.times do |col|
          color = row < 3 ? :black : :white
          add = row.odd? == col.even?
          add_piece(Piece.new([row, col], color, self)) if add
        end
      end
    end

    def is_jump_move?(piece, sequence)
      sequence.size > 1 || (sequence.first.first - piece.pos.first).abs > 1
    end
end

class Array
  def deep_dup
    self.map { |el| el.is_a?(Array) ? el.deep_dup : (el.nil? ? nil : el) }
  end
end

class HumanPlayer
  def initialize(color)
    @color = color
  end

  def play_turn(board)
    puts "#{@color.to_s.capitalize} turn!"
    puts board.render
    puts "Type a sequence of coordinates you would like to move to (Ex: 2,1 3,2)"
    coordinates = gets.chomp.split
    coordinates.map { |coord| parse_coordinates(coord.split(",")) }
  end

  def parse_coordinates(str)
    str.map { |s| Integer(s) }
  end
end

class Game
  def initialize
    @players = {
      :white => HumanPlayer.new(:white),
      :black => HumanPlayer.new(:black)
    }
    @board = Board.new
  end

  def play
    turn = :black
    until over?
      begin
        sequence = @players[turn].play_turn(@board)
        @board.perform_moves(sequence, turn)
      rescue StandardError => e
        puts e.message.bold
        retry
      end
      turn = turn == :black ? :white : :black
    end

    if (won?)
      puts "#{won?.to_s.upcase} WINS"
    else
      puts "IT'S A DRAW"
    end
  end

  def draw?
    @board.all_pieces.all? { |piece| piece.moves.empty? }
  end

  def over?
    draw? || won?
  end

  def won?
    colors = @players.keys
    colors.each do |color|
      won = @board.all_pieces{ |pc| pc.color == color }
        .all? { |piece| piece.moves.empty? }
      return color if won
    end

    false
  end
end