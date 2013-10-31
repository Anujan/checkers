require "colorize"
class Piece
  attr_accessor :pos, :color, :king, :board
  DIAGS = {
    :black => [[1,1], [1, -1]],
    :white => [[-1, 1], [-1, 1]]
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
      next if (self.board[diag_pos].nil? || !self.board[jump_diags[idx]].nil? || self.board[diag_pos].color == self.color)
      moves << jump_diags[idx]
    end
    moves
  end

  def moves
    jumps = jump_moves
    jumps.empty? ? {:moves => slide_moves, :jump => false}
    : {:moves => jump_moves, :jump => true}
  end

  def pos=(value)
    @pos = value
    @board.add_piece(self)
  end

  def symbol
    if (self.color == :white)
      self.kinged? ? "o" : "o"
    else
      self.kinged? ? "o" : "o"
    end
  end
end

class InvalidMoveError < StandardError
end

class Board
  attr_accessor :pieces
  def initialize(pieces=nil)
    if (pieces.nil?)
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

  def display
    colored = true
    pieces.each do |row|
      row.each do |piece|
        symbol = (piece.nil? ? " " : " #{piece.symbol} ").rjust(3)
        bg = colored ? :default : :green
        color =   piece.nil? ? :default : piece.color
        print symbol.colorize(background: bg, color: color)
        colored = !colored
      end
      colored = !colored
      puts
    end
    nil
  end

  def off_the_grid?(pos)
    pos[0] < 0 || pos[0] > 7 || pos[1] < 0 || pos[1] > 7
  end

  def dup
    new_pieces = pieces.deep_dup
    new_board = Board.new(new_pieces)
  end

  def perform_slide(piece, end_pos)
    raise InvalidMoveError, "That piece can't move there" unless piece.slide_moves.include?(end_pos)
    piece.pos = end_pos
    true
  end

  def perform_jump(piece, end_pos)
    piece_between = piece.pos.map.with_index do |el, i|
      el + ((end_pos[i] - piece.pos[i]) / 2)
    end
    p "Piece Between #{piece_between}}"
    raise InvalidMoveError, "No piece to jump at #{piece_between}"
    remove_piece(piece_between)
    piece.pos = end_pos
    true
  end

  def jumper_pieces(color)
    pieces.flatten.compact.select { |piece| !piece.jump_moves.empty? }
  end

  def perform_moves!(sequence)
    start_pos = sequence.shift
    piece = self[start_pos]
    raise InvalidMoveError, "No piece at #{start_pos}" if piece.nil?
    if (sequence.size > 1 || (sequence.first.first - piece.pos.first) > 1)
      raise InvalidMoveError, "This piece can't jump there..." unless piece.jump_moves.include?(sequence.first)
      until sequence.empty?
        perform_jump(piece, sequence.shift)
      end
      raise InvalidMoveError, "Jumping is mandatory if you're able to" unless piece.jump_moves.empty?
    else
      raise InvalidMoveError, "You have a piece that's able to jump, so you have to jump." unless jumper_pieces.empty?
      perform_slide(piece, sequence.first)
    end
  end

  protected
    def []=(pos, val)
      pieces[pos[0]][pos[1]] = val
    end

    def build_board
      rows = (0..2).to_a + (5..7).to_a
      rows.each do |row|
        8.times do |col|
          color = row < 3 ? :black : :white
          add = (color == :black && row.even? != col.odd?) || (color == :white && row.odd? == col.even?)
          add_piece(Piece.new([row, col], color, self))
        end
      end
    end
end

class Array
  def deep_dup
    self.map { |el| el.is_a?(Array) ? el.deep_dup : el.dup }
  end
end

class Game
end