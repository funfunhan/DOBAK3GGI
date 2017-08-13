# Encoding: UTF-8
require 'gosu'
require 'chipmunk'
require 'singleton'
require 'slave'
require "xmlrpc/client"
require 'childprocess'
require 'rbconfig'

WIDTH, HEIGHT = 1000, 700
NUM_OF_DECKS = 2
UI_PIVOT = 50
INITIAL_MONEY = 30
BET_UNIT = 1
INIT_BET_MONEY = 1
SCHOOL_MONEY = 1

# Layering of sprites
module ZOrder
  Board, Card, Mouse = 0, 1, 2
end

def is_port_open?(port)
  begin
    s = TCPServer.new("127.0.0.1", port)
  rescue Errno::EADDRINUSE
    return false
  end
  s.close
  return true
end

# Detection of OS
def is_windows?
  case RbConfig::CONFIG['host_os']
  when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    return true
  else
    return false
  end
end

class IndianPoker < Gosu::Window

  def shuffle_cards
    @future_deck = Array.new
    (1..10).to_a.each do |x|
      2.times do |y|
        @future_deck << x
      end
    end
    @future_deck.shuffle!
    @current_deck = @future_deck.pop(2)
    if @sun_player == @players[0]
      @players[0].card_number = @current_deck[0]
      @players[1].card_number = @current_deck[1]
    else
      @players[0].card_number = @current_deck[1]
      @players[1].card_number = @current_deck[0]
    end
    @past_deck = Array.new
  end

  def go_to_school
    @bet_money_history = Array.new
    @bet_money_history << SCHOOL_MONEY
    @bet_money_history << SCHOOL_MONEY
    @players[0].money -= SCHOOL_MONEY
    @players[1].money -= SCHOOL_MONEY
  end

  def init_game
    @servers = Array.new
		@players.clear
		@players[0] = Player.new(0)
		@players[1] = Player.new(1)
    @play_turn = @players[0]
    @play_next = @players[1]
    @current_bet_money = INIT_BET_MONEY

    go_to_school

    @current_time_for_longbutton = Time.now
    @bet_violation_cnt = 0
    @gameover = false
    @betover = false
    @end_game = false
    @remaining_deck = NUM_OF_DECKS
    @sun_player = @players[0] #선플레이어

    shuffle_cards

    #Load AI
    ais = Dir.entries(".").map {|x| x if /^ai_[[:alnum:]]+.rb$/.match(x)}.compact
    xml_port = 8000
    slaves = Array.new
    ais.each do |x|
      (xml_port..8080).to_a.each do |p|
        if is_port_open?(p)
          xml_port = p
          break
        end
      end
      if is_windows?
        slaves << ChildProcess.build("ruby", x, xml_port.to_s).start
      else
        slaves << Slave.object(:async => true){ `ruby #{x} #{xml_port}` }
      end
      @servers << XMLRPC::Client.new("localhost", "/", xml_port)
      xml_port += 1
    end

    0.upto(@servers.size - 1) do |count|
      server_connection = false
      while !server_connection
        begin
          @players[count].player_name = @servers[count].call("indian.get_name")
          @players[count].ai_flag = true
          server_connection = true
        rescue Errno::ECONNREFUSED
        end
      end
    end
  end

  def initialize
    super(WIDTH, HEIGHT, false)
    self.caption = '인디언포커!'

    @players = Array.new(2)
    @board  = Board.instance
    @font = Gosu::Font.new(self, Gosu::default_font_name, 18)
    @font_2x = Gosu::Font.new(self, Gosu::default_font_name, 24)
    @font_3x = Gosu::Font.new(self, Gosu::default_font_name, 30)
    @font_4x = Gosu::Font.new(self, Gosu::default_font_name, 36)
    @font_5x = Gosu::Font.new(self, Gosu::default_font_name, 42)

    init_game
  end

  def draw
    @board.draw

    @players.each { |player| player.draw }

    betover_opacity = @betover || @gameover ? 0xff_ffffff : 0x66_ffffff
    gameover_opacity = @gameover ? 0xff_ffffff : 0x66_ffffff
    # winner_opacity = @gameover ? 0xff_ffffff : 0x33_ffffff

    @font_4x.draw_rel("베팅 중", 500, 170, 1.0, 0.5, 0.0)
    @font_4x.draw_rel("베팅 끝", 500, 220, 1.0, 0.5, 0.0, 1, 1, betover_opacity)
    @font_4x.draw_rel("오픈", 500, 270, 1.0, 0.5, 0.0, 1, 1, gameover_opacity)
    if @end_game
      @font_5x.draw_rel("----- 끝 -----", 500, 340, 1.0, 0.5, 0.0, 1, 1, gameover_opacity)
    end

    # @font.draw("현재 턴 : #{@play_turn.player_name}", 720, UI_PIVOT + 40, 1.0, 1.0, 1.0)
    # @font.draw("왼쪽카드 히든 : Q", 720, UI_PIVOT + 60, 1.0, 1.0, 1.0)
    # @font.draw("오른쪽카드 히든 : W", 720, UI_PIVOT + 80, 1.0, 1.0, 1.0)

    pivot_font_y_position = [UI_PIVOT + 150, UI_PIVOT + 220]
    ui_index = 0
    position = ["LEFT", "RIGHT"]
    total_bet = Array.new
    total_bet[0] = if @play_turn == @players[1] then get_your_total_bet else get_my_total_bet end
    total_bet[1] = if @play_turn == @players[1] then get_my_total_bet else get_your_total_bet end

    @players.each_with_index do |player, index|

      x_position = [220, WIDTH-220]
      bet_position = [420, WIDTH-420]

      @font.draw_rel("베팅", bet_position[index], 520, 1.0, 0.5, 0.0)
      if @players[0].died || @players[1].died
        @font_3x.draw_rel("#{total_bet[index-1]}", bet_position[index], 545, 1.0, 0.5, 0.0)
      else
        @font_3x.draw_rel("#{total_bet[index]}", bet_position[index], 545, 1.0, 0.5, 0.0)
      end

      player_name_opacity = (!@betover && !@gameover && @play_turn != player) ? 0x66_ffffff : 0xff_ffffff
      @font_2x.draw_rel(player.player_name, x_position[player.number], 65, 1.0, 0.5, 0.0, 1, 1, player_name_opacity)

      # @font_4x.draw_rel("●", 450, 300, 1.0, 0.5, 0.0, 1, 1, winner_opacity)

      if !@betover && !@gameover && @play_turn == player
        @font_2x.draw_rel("▼", x_position[player.number], 30, 1.0, 0.5, 0.0)

        unless player.ai_flag
          @font.draw_rel("+", bet_position[index], 578, 1.0, 0.5, 0.0)
          @font_2x.draw_rel("◀　#{@current_bet_money}　▶", bet_position[index], 601, 1.0, 0.5, 0.0)

          @font.draw_rel("C - 콜", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 630, 1.0, 0.0, 0.0)
          @font.draw_rel("F - 폴드", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 650, 1.0, 0.0, 0.0)
          @font.draw_rel("N - 레이즈", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 670, 1.0, 0.0, 0.0)
        else
          @font.draw_rel("N - 다음 턴 연산하기", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 670, 1.0, 0.0, 0.0)
        end

      elsif @betover
        @font.draw_rel("N - 카드 오픈", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 670, 1.0, 0.0, 0.0)
      elsif @gameover
        @font.draw_rel("N - 다음 게임", 160 + @font.text_width("R - 새로 시작하기") + @font.text_width("P - 턴 넘기기"), 670, 1.0, 0.0, 0.0)
      end

      @font.draw_rel("보유 칩", x_position[index], 520, 1.0, 0.5, 0.0)
      @font_3x.draw_rel("#{player.money}", x_position[index], 545, 1.0, 0.5, 0.0)

    end

    total_bet_money = @bet_money_history.inject(0, :+)

    @font.draw_rel("판돈", 500, 430, 1.0, 0.5, 0.0)
    @font_3x.draw_rel("#{total_bet_money}", 500, 455, 1.0, 0.5, 0.0)

    @font.draw_rel("배팅 위반 - #{@bet_violation_cnt}", 600, 670, 1.0, 0.5, 0.0)


    # @font.draw_rel("(사람) 배팅금액 : ", 500, UI_PIVOT + 450, 1.0, 0.5, 0.0)
    # @font.draw_rel("#{@current_bet_money}", 600, UI_PIVOT + 450, 1.0, 0.5, 0.0)
    # @font.draw_rel("(사람) 배팅금액 업 : Up, 다운 : Down", 500, UI_PIVOT + 470, 1.0, 0.5, 0.0)

    @font.draw_rel("R - 새로 시작하기", 100, 670, 1.0, 0.0, 0.0)
    @font.draw_rel("P - 턴 넘기기", 130 + @font.text_width("R - 새로 시작하기"), 670, 1.0, 0.0, 0.0)

    @font.draw_rel("멋쟁이 사자처럼", 900, 670, 1.0, 1.0, 0.0)
  end

  def needs_cursor?
    true
  end

  def restart
    init_game
  end

  def pass_turn
    @current_bet_money = INIT_BET_MONEY
    @bet_violation_cnt = 0
    @play_turn, @play_next = if @play_turn == @players[0]
                      [@players[1], @players[0]]
                   elsif @play_turn == @players[1]
                      [@players[0], @players[1]]
                   end
  end

  def set_sun(id)
    if id == 1
      @sun_player = @players[1]
      @play_turn = @players[1]
      @play_next = @players[0]
    elsif id == 0
      @sun_player = @players[0]
      @play_turn = @players[0]
      @play_next = @players[1]
    else
      @play_turn = @sun_player
      if @play_turn == @players[0]
        @play_next = @players[1]
      else
        @play_next = @players[0]
      end
    end
  end

  def calculate

    if @end_game

    elsif @gameover
      #돈 나눠주기
      total_money = 0
      @bet_money_history.each { |x| total_money += x.to_i }
      @bet_money_history.clear
      if @players[0].died
        @players[1].money += total_money
        set_sun(1)
      elsif @players[1].died
        @players[0].money += total_money
        set_sun(0)
      elsif @players[0].card_number > @players[1].card_number
        @players[0].money += total_money
        set_sun(0)
      elsif @players[0].card_number < @players[1].card_number
        @players[1].money += total_money
        set_sun(1)
      else
        @players[0].money += total_money / 2
        @players[1].money += total_money / 2
        set_sun(-1)
      end


      if @play_turn.money <= 0 || @play_next.money <= 0
        @end_game = true
      else

        go_to_school

        #다시 시작
        @gameover = false
        if @future_deck.size < 2
          @remaining_deck -= 1
          if @remaining_deck == 0
            @gameover = true
            @end_game = true
          else
            shuffle_cards
          end
        else
          @past_deck << @current_deck
          @past_deck.flatten!
          @current_deck = @future_deck.pop(2)
          if @sun_player == @players[0]
            @players[0].card_number = @current_deck[0]
            @players[1].card_number = @current_deck[1]
          else
            @players[0].card_number = @current_deck[1]
            @players[1].card_number = @current_deck[0]
          end
        end

        [0, 1].each do |x|
          @players[x].hide = true
          @players[x].died = false
        end

      end

    elsif @betover
      @gameover = true
      @betover = false
      [0, 1].each {|x| @players[x].hide = false }
    else
      if @play_turn.ai_flag
        bet_money, win_percant, left_card_list, can_win_to_enemy_card_count, round, pRival, pMine, pRBet, pMBet, myCoinHistory, rivalCoinHistory=
          @servers[@play_turn.number].call(
                  "indian.calculate",
                  [@play_next.card_number] + [@past_deck] + [@play_turn.money] + [@bet_money_history]
                )
        #Log
        ai_name = @servers[@play_turn.number].call("indian.get_name")
        puts "\n\n--------------- ROUND : " + round.to_s + "---------------"
        print "현재 AI 이름 : "
        puts ai_name
        puts "이전 판까지의 사용된 카드"
        print @past_deck
        puts "\n상대방 카드"
        puts @play_next.card_number
        puts "상대방 카드 + 남은 카드를 통한 이길 확률"
        puts win_percant
        puts "남은 카드수 (지금까지 카드 + 상대방 카드)"
        print left_card_list
        puts "\n남은 카드중 상대방 카드를 이길 수 있는 카드 수"
        puts can_win_to_enemy_card_count
        print "\n상대방의 패 기록 : "
        print pRival
        print "\n나의 패 기록("+ai_name+") : "
        print pMine
        print "\n상대방 배팅 기록 : "
        print pRBet
        print "\n나의 배팅 기록("+ai_name+") : "
        print pMBet
        print "\n상대방 가진 코인 기록 : "
        print rivalCoinHistory
        print "\n나의 가진 코인 기록("+ai_name+") : "
        print myCoinHistory
        puts  "\n\n이번 라운드 배팅 기록"
        print @bet_money_history
        puts "\n나의 배팅 머니("+ai_name+")"
        puts bet_money.to_i
        # puts message
        puts "-----------------------------------------------\n\n"
      else
        bet_money = @current_bet_money
      end

      # Update Game Status
      if bet_money.to_i < 0 #DIE
        @play_turn.died = true
        @betover = true
        pass_turn
      elsif get_your_total_bet > (get_my_total_bet + bet_money.to_i)
        #이런일이 발생하면 안된다. # 배팅액은 맞춰야 한다
        @bet_violation_cnt += 1
      elsif bet_money.to_i == 0
        #이런일이 발생하면 안된다. # 0원 배팅은 없다.
        @bet_violation_cnt += 1
      else
        if get_your_total_bet == (get_my_total_bet + bet_money.to_i) || @play_turn.money <= 0 || @play_next.money <= 0
          @betover = true
        end
        @bet_money_history << bet_money.to_i
        @play_turn.money -= bet_money.to_i if bet_money.to_i > 0
        pass_turn
      end
    end
  end

  def hide_toggle(id)
    @players[id].hide_toggle
  end

  def button_down(id)
    case id
    when Gosu::KbR
      restart
    when Gosu::KbP
      pass_turn
    when Gosu::KbN
      calculate
    when Gosu::KbQ
      hide_toggle(0)
    when Gosu::KbW
      hide_toggle(1)
    when Gosu::KB_RIGHT
      @current_bet_money += BET_UNIT if @play_turn.money > @current_bet_money && @play_next.money + get_your_total_bet > @current_bet_money + get_my_total_bet
    when Gosu::KB_LEFT
      @current_bet_money -= BET_UNIT if @current_bet_money > -1
    when Gosu::KbC
      if @bet_money_history.empty?
        @current_bet_money = 0
      else
        @current_bet_money = get_your_total_bet - get_my_total_bet
      end
      calculate
    when Gosu::KbF
      @current_bet_money = 0 - BET_UNIT
      calculate
    end
  end

  def update
    if Gosu.button_down? Gosu::KB_RIGHT
      @current_bet_money += BET_UNIT if Time.now - @current_time_for_longbutton > 0.5 && @play_turn.money > @current_bet_money && @play_next.money + get_your_total_bet > @current_bet_money + get_my_total_bet
    elsif Gosu.button_down? Gosu::KB_LEFT
      @current_bet_money -= BET_UNIT if Time.now - @current_time_for_longbutton > 0.5 && @current_bet_money > -1
    else
      @current_time_for_longbutton = Time.now
    end
  end

  private
  def get_your_total_bet
    total = 0
    1.upto(@bet_money_history.size) do |index|
      total += @bet_money_history[0 - index] if index.odd?
    end
    return total
  end

  def get_my_total_bet
    total = 0
    1.upto(@bet_money_history.size) do |index|
      total += @bet_money_history[0 - index] unless index.odd?
    end
    return total
  end
end

class Board
  include Singleton
  def initialize
    @image = Gosu::Image.new("media/board_logo.jpg")
  end

  def draw
    image_resize_ratio = HEIGHT / @image.height.to_f
    @image.draw(0, 0, ZOrder::Board, image_resize_ratio, image_resize_ratio)
  end
end

class Player
  attr_reader :stones, :color
  attr_accessor :player_name, :ai_flag, :number, :money, :hide, :card_number, :died
  def initialize(number)
    @died = false
    @hide = true
    @money = INITIAL_MONEY
    @number = number
    @stones = Array.new
    @player_name = "사람_#{Array.new(6){rand(10)}.join}"
    @ai_flag = false

    # initialize card images
    @images = Array.new
    (1..10).to_a.each do |x|
      @images[x] = Gosu::Image.new("media/#{x}_of_spades.png")
    end

    # keyboard Q & W
    @hidden_cards = [Gosu::Image.new("media/q.png"), Gosu::Image.new("media/w.png")]
  end

  def draw
      card_width_quarter = @images[@card_number].width*0.25
      x_position = [220-card_width_quarter, WIDTH-220-card_width_quarter]
    if @hide
      @hidden_cards[@number].draw(x_position[@number], 110, ZOrder::Card, 0.5, 0.5)
    else
      @images[@card_number].draw(x_position[@number], 110, ZOrder::Card, 0.5, 0.5)
    end
  end

  def hide_toggle
    @hide = !@hide
  end

end

@window = IndianPoker.new
@window.show
