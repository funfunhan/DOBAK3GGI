require "xmlrpc/server"
require "socket"

s = XMLRPC::Server.new(ARGV[0])
MIN_DEFAULT_BET = 1

class MyAi
  @@pRival=[] # 10라운드까지 저장
  @@pMine=[]  # 10라운드까지 저장
  @@pRBet = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]  # 지금까지의 상대의 베팅 기록
  @@pMBet = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
  @@MyCoinHistory = []
  @@RivalCoinHistory = []
  @@firstOrlast = []
  @@round = 0
  @@roundoffset = 0

  def calculate(info)
    opposite_play_card = info[0] # 상대방이 들고 있는 카드의 숫자
    past_cards = info[1]         # 지금까지 지나간 카드들 (배열)
    my_money = info[2]           # 내가 가지고 있는 칩
    bet_history = info[3]        # 이때까지 나와 상대방이 판에 깔았던 칩들 (배열)

    your_total_bet, my_total_bet = get_total_bet_money_per_person bet_history
    this_bet = your_total_bet - my_total_bet

    if this_bet == 0
      this_bet = MIN_DEFAULT_BET
    end


    # Write your own codes here
    #게임 시작
    @rival_average_betting = 0
    @rival_card_history = []
    @my_card_history = []
    eachround = 0
    maxindex = 0
    if (bet_history.count / 2) == 1
      @@round = @@round + 1
      if @@roundoffset == 0
        if @@round != (past_cards.count/2) + 1
          @@firstOrlast.push(0)
          #이전라운드 추가 기록 + round + 1
          ## round가 1개 적게 카운트 된 정보를 먼저 입력
          @@MyCoinHistory.push(my_money)
          @@RivalCoinHistory.push(60-(my_money))
          @@pRBet[(@@round-1)] = 1
          @@pMBet[(@@round-1)] = 1

          ## 이후 round 를 정상화시켜 다시 입력
          @@round = @@round + 1
          @@firstOrlast.push(1)
          @@MyCoinHistory.push(my_money+1)
          @@RivalCoinHistory.push(60-(my_money+1))

          maxindex = (@@firstOrlast.length-1)
          while eachround < maxindex
            if @@firstOrlast[eachround] == 1
              @my_card_history.push(past_cards[(eachround*2)])
              @rival_card_history.push(past_cards[(eachround*2)+1])
              eachround = eachround + 1
            else
              @my_card_history.push(past_cards[(eachround*2) +1])
              @rival_card_history.push(past_cards[(eachround*2)])
              eachround = eachround + 1
            end
          end
          @rival_card_history.push(opposite_play_card)

        else
          #기본 로직
          if (bet_history.count % 2) == 0
            @@firstOrlast.push(1)
          else
            @@firstOrlast.push(0)
          end

          @@MyCoinHistory.push(my_money+1)
          @@RivalCoinHistory.push(60-(my_money+1))

          if @@round != 1 && @@round != 11
            maxindex = (@@firstOrlast.length-1)
            while eachround < maxindex
              if (@@firstOrlast[eachround] == 1)
                @my_card_history.push(past_cards[(eachround*2)])
                @rival_card_history.push(past_cards[(eachround*2)+1])
                eachround = eachround + 1
              else
                @my_card_history.push(past_cards[(eachround*2) +1])
                @rival_card_history.push(past_cards[(eachround*2)])
                eachround = eachround + 1
              end
            end
          end
          @rival_card_history.push(opposite_play_card)
        end

      else
        @my_card_history = @my_card_history + @@pMine
        @rival_card_history = @rival_card_history + @@pRival
        if @@round != (past_cards.count/2) + 11
          @@firstOrlast.push(0)
          @@MyCoinHistory.push(my_money)
          @@RivalCoinHistory.push(60-(my_money))
          @@pRBet[(@@round-1)] = 1
          @@pMBet[(@@round-1)] = 1

          ## 이후 round 를 정상화시켜 다시 입력
          @@round = @@round + 1
          @@firstOrlast.push(1)
          @@MyCoinHistory.push(my_money+1)
          @@RivalCoinHistory.push(60-(my_money+1))

          if @@round != 11
            maxindex = (@@firstOrlast.length-1)
            eachround = 10
            while eachround < maxindex
              if @@firstOrlast[eachround] == 1
                @my_card_history.push(past_cards[((eachround-10)*2)])
                @rival_card_history.push(past_cards[((eachround-10)*2)+1])
                eachround += 1
              else
                @my_card_history.push(past_cards[((eachround-10)*2) +1])
                @rival_card_history.push(past_cards[((eachround-10)*2)])
                eachround += 1
              end
            end
          end
          @rival_card_history.push(opposite_play_card)

        else
          if bet_history.count % 2 == 0
            @@firstOrlast.push(1)
          else
            @@firstOrlast.push(0)
          end
          #기본 로직
          @@MyCoinHistory.push(my_money+1)
          @@RivalCoinHistory.push(60-(my_money+1))

          if @@round != 11
            maxindex = (@@firstOrlast.length-1)
            eachround = 10
            while eachround < maxindex
              if @@firstOrlast[eachround] == 1
                @my_card_history.push(past_cards[((eachround-10)*2)])
                @rival_card_history.push(past_cards[((eachround-10)*2)+1])
                eachround += 1
              else
                @my_card_history.push(past_cards[((eachround-10)*2) +1])
                @rival_card_history.push(past_cards[((eachround-10)*2)])
                eachround += 1
              end
            end
          end
          @rival_card_history.push(opposite_play_card)
        end
      end
    end


    if (@@RivalCoinHistory[(@@round-2)] - @@RivalCoinHistory[(@@round-1)]).abs == @@pRBet[@@round-2]
      @@pRBet[(@@round-1)] = your_total_bet
    else
      if @@firstOrlast[(@@round-1)] == 1
        if (@@MyCoinHistory[(@@round-2)] - @@MyCoinHistory[(@@round-1)]).abs == @@pRBet[@@round-2]
          @@pRBet[(@@round-1)] = your_total_bet
        else
          @@pRBet[(@@round-2)] = (@@MyCoinHistory[(@@round-2)] - @@MyCoinHistory[(@@round-1)]).abs
          @@pRBet[(@@round-1)] = your_total_bet
        end
      else
        @@pRBet[(@@round-2)] = (@@RivalCoinHistory[(@@round-2)] - @@RivalCoinHistory[(@@round-1)]).abs
        @@pRBet[(@@round-1)] = your_total_bet
      end
    end

    if @@round != 1
      @rival_average_betting = (@@pRBet.take((@@round-1)).inject(0){|sum,x| sum + x }) / (@@round-1)
    end


    ## 남은 카드
    ### 남은 카드 리스트
    new_past_cards = past_cards
    new_past_cards.push(opposite_play_card)
    left_card_list = []
    is_use_card = 2
    for card_number_counting in 1..10
      is_use_card = new_past_cards.count(card_number_counting)
      case is_use_card
      when 0 then
        left_card_list.push(card_number_counting)
        left_card_list.push(card_number_counting)
      when 1 then
        left_card_list.push(card_number_counting)
      else
        next
      end
    end
    ### 남은 카드 리스트의 총 갯수
    left_card_count = left_card_list.count



    ## 확률 계산
    ### 상대방 패보다 내 패가 좋을 때 카드 개수(+ 안 좋을때 카드 개수)
    can_win_to_enemy_card_count = left_card_list.count { |left_each_card_number| left_each_card_number >= opposite_play_card }
    real_can_win_to_enemy_card_count = left_card_list.count { |left_each_card_number| left_each_card_number > opposite_play_card }
    can_draw_to_enemy_card_count = left_card_list.count { |left_each_card_number| left_each_card_number = opposite_play_card }
    can_lose_to_enemy_card_count = left_card_list.count - can_win_to_enemy_card_count

    ### 상대방 패를 이길 확률 (+ 질 확률)
    win_percent = (can_win_to_enemy_card_count.to_f / left_card_list.count.to_f) * 100.0
    real_win_percent = (real_can_win_to_enemy_card_count.to_f / left_card_list.count.to_f) * 100.0
    draw_percent = (can_draw_to_enemy_card_count.to_f / left_card_list.count.to_f) * 100.0
    lose_percent = 100.0 - win_percent
    can_lose_percent = 100.0 - real_win_percent

    ## 라운드가 10일떄는 상대방의 패와 나의 패 모두 알 수 있으므로 바로 저장
    if @@round == 10
      if @@roundoffset == 0
        @@pRival = @@pRival + @rival_card_history
        @@pMine =@@pMine +  @my_card_history
        @@pMine.push(left_card_list.last)
        @@roundoffset = 1
      end
    end

    ##배팅에 대한 로직 설정
    ##########################################################################################
    # 기본 로직
    ## 1. 선공일 경우
    ### 승리 확률이 60% 이상일때 배팅을 한다.
    ### 10%단위로 배팅 금액을 1씩 올린다. ex) 60% = 1배팅 70% 2배팅
    ### 각 단위(60,70,80,90%)의 배팅 상한선은 3,3,4,4로 고정한다.
    ### 단, 100%일 경우 초기 배팅 금액은 3으로 고정하지만 추가 배팅은 무한으로 설정한다.

    ## 2. 후공일 경우
    ### 상대방의 배팅률 + 나의 승리 확률에 따라 배팅을 한다.
    ### 상대방의 배팅이 3이상이 진행 되었을 때 나의 승리 확률이 70% 이상일 때만 배팅에 응한다.
    ### 나의 승리 확률이 80% 이상이면 추가 배팅을 시도한다. (상대방 배팅 금액 / 2 를 추가로한다.)
    ### 단, 추가 배팅 상한선은  80% = 5, 90% = 7, 100% = 무제한 이다.


    # 변칙 로직
    ## 1. 남은 라운드와 상대와 나의 코인 수를 비교하여 ALL die를 하여도 이길수 있으면 All die를 한다.
    ### 계산 방법 : ()상대방과 나의 코인 차이 / 남은 라운드 수 ) > 2 이면 ALL die를 하여도 경기를 이긴다.

    ## 2. 남은 라운드 수를 그룹화를 하여 각 그룹화 일때의 배팅 가능한 승리 확률 기준을 조절한다.
    ### 총 20라운드(남은 라운드로 계산 하면 19 ~ 0 이다)에서 덱을 2개를 사용하므로 1~10 | 11~20 이 비슷한 패턴을 가진다.
    #### 7라운드 부터 이전 라운드까지 진행된 데이터를 기반으로 배팅 방식에 변화를 준다.
    #### 10라운드, 20라운드는 상대방과 나의 카드를 모두 알 수 있으므로 확률(0% or 100%)에 따라 die or 무한 betting을 한다.
    ### 1라운드 그룹
    ### 2~3라운드 그룹
    ### 4~6라운드 그룹
    ### 7~8 라운드 그룹
    ### 9라운드 그룹
    ### 10라운드 그룹

    ## 3. 랜덤변수를 추가하여 변칙적인 배팅을 한다.
    ### 현재 나의 상황에 따른 블러핑을 시도한다. - 나의 승리 확률이 70% 이하일떄 시도하도록 한다.
    #### A. 많이 앞설때  = 블러핑을 할 확률을 대폭 줄인다 (약 3%미만)
    #### B. 상대와 비슷할떄(이기고 있을떄) = 블러핑 할 확률을 약 6%로 설정하여 블러핑을 간혹 시도한다.
    #### C. 상대와 비슷할떄(지고 있을떄) = 블러핑 할 확률을 약 8%로 설정하여 블러핑을 간혹 시도한다.
    #### D. 상대방이 나보다 많이 앞설때 = 블러핑 할 확률을 약 10%로 설정하여 블러핑을 간혹 시도한다.
    ### 각 확률에 따른 배팅 정도(상한선은 정해져 있찌만 초기 배팅 + 추가 배팅에 대해서는 정해져 있지 않다.)를 랜덤하게 설정한다.
    #### 예를 들어 15~12그룹에서 승리 확률이 70%일때 3개 배팅이 상한 선일때 - 배팅 방법이 3 | 1 -> 2 | 2-> 1 가 있는데 이를 랜덤하게 설정한다.

    ## 4. 상대방의 배팅에 대해서 분석 후 추가적인 배팅 로직을 설정한다.
    ### 15~12그룹 부터 19~16그룹(라운드)에서 얻은 데이터를 바탕으로 상대방의 배팅 정도를 분석한다.
    ### 배팅 정도를 분석은 매 라운드 새롭게 갱신된다.
    ### 분석된 배팅 정도에 따라서 나의 배팅 로직을 수정한다.
    #### A. 상대방의 평균 배팅 정도를 기준으로 나의 배팅을 플러스 시킨다. -(배팅 정도 = 상대방이 매 라운드 승률이 총 60% 이상일때 총 거는 배팅의 수)
    #### ex) 상대방의 배팅정도의 평균이 약 3일 때 우리의 배팅 을 평균/2 를 항상 추가적으로 상한선에 더해준다.
    #### B. 상대방의 배팅로직에서 많은 수의 배팅(6개 이상)이 자주 나타날 때 상대방의 승리 확률을 계산해서 블러핑 인지 확인한다.
    #### 블러핑이 아니라면 상대방의 승률을 저장한 후 다음 라운드에서 상대방의 배팅이 일정 이상으로 또 나온다면 저장된 정보를 토대로 나의 카드의 승률을 유추 하도록 한다.

    ## 5. ??????

    ##########################################################################################


    # 변칙로직 1 - 무조건 승리에 대한 코드
    ## 코인 갯수 차이
    ### 코인 갯수 차이 계산 (a+b = 58 <=> b = 58-a <=> a-b = a-(58-a) = 2a-58)
    gab_coin = @@MyCoinHistory.last - @@RivalCoinHistory.last
    ### 현재 라운드의 코인 갯수 차이가 남은 라운드 수의 두 배가 넘을 경우 무조건 승리

    victory = false
    stability = gab_coin / ((21 - @@round).to_f)
    # stablity는 안정도로 2보다 큰 경우에 무조건 이김 (2면 비김)
    if stability > 2
      victory = true
    end


    # 변칙로직 2 - 그룹별 승리 확률 계산 및 적용
    ##



    # 변칙로직 3 - 랜덤 변수 활용
    ## 랜덤변수 선언



    # 변칙로직 4 - 상대방 배팅에 대해서 분석 후 추가 배팅 로직 설정
    ## 배팅 로직 설정



    # MAXBETTING
    maxbetting = 0

    if victory == true
      this_bet = -1
    else
      ## 배팅 방법
      ### 선공일때
      if (bet_history.count % 2) == 0
        if @@round == 1
          ## 기초 로직
          randomNumForBetting = rand(1..100)
          if opposite_play_card == 1              ##상대 카드가 1일때 = 무한
            if your_total_bet > my_total_bet      # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if randomNumForBetting < 33         #랜덤 확률(33% 이하)
                this_bet = your_total_bet - my_total_bet + 1    #상대방이 건 배팅 보다 무조건 1더 많게 건다. (무제한 배팅)
              elsif randomNumForBetting < 66 && randomNumForBetting >= 33       #랜덤 확률(33% 이상 66% 미만)
                this_bet = your_total_bet - my_total_bet + 2    #상대방이 건 배팅 보다 무조건 2더 많게 건다. (무제한 배팅)
              else  #랜덤 확률(66% 이상 100% 미만)
                this_bet = your_total_bet - my_total_bet + 3   #상대방이 건 배팅 보다 무조건 3더 많게 건다. (무제한 배팅)
              end

            else  # 내가 선공이므로 시작 배팅 (1,2,3 중 시작 배팅 랜덤 선택)
              if randomNumForBetting < 33
                this_bet = 1
              elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                this_bet = 2
              else
                this_bet = 3
              end
            end


          elsif opposite_play_card == 2    ##상대 카드가 2일때
            maxbetting = 5
            if your_total_bet > my_total_bet  # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting  # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1
              else    # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end

            else # 시작 배팅
              if my_total_bet == 1
                if randomNumForBetting < 25
                  this_bet = 1 # bet = 2
                elsif randomNumForBetting < 50 && randomNumForBetting >= 25
                  this_bet = 2 # bet = 3
                elsif randomNumForBetting < 75 && randomNumForBetting >= 50
                  this_bet = 3 # bet = 4
                else
                  this_bet = 4 # bet = 5
                end
              end
            end

          elsif opposite_play_card == 3 ##상대 카드가 3일때
            maxbetting = 4
            if your_total_bet > my_total_bet # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1 # die
              else # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end
            else # 시작 배팅
              if my_total_bet == 1
                if randomNumForBetting < 33
                  this_bet = 1 # bet = 2
                elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                  this_bet = 2 # bet = 3
                else
                  this_bet = 3 # bet = 4
                end
              end
            end


          elsif opposite_play_card == 4
            maxbetting = 3
            if your_total_bet > my_total_bet # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1 # die
              else # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end
            else # 시작 배팅
              if my_total_bet == 1
                if randomNumForBetting < 50
                  this_bet = 1 # bet = 2
                else
                  this_bet = 2 # bet = 3
                end
              end
            end

          elsif opposite_play_card >= 8 #상대방 카드가 8이상이면 무조건 다이
            this_bet = -1

          else # 상대방의 카드가 5,6,7일때 1개는 배팅해본다.
            maxbetting = 2
            if your_total_bet > my_total_bet # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              this_bet = -1
            else # 시작 배팅
              this_bet = 1
            end
          end

        elsif @@round == 2
          ## 기초 로직

          randomNumForBetting = rand(1..100)
          if win_percent >= 99              ##상대 카드가 1일때 = 무한
            if your_total_bet > my_total_bet      # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if randomNumForBetting < 33         #랜덤 확률(33% 이하)
                this_bet = your_total_bet - my_total_bet + 1    #상대방이 건 배팅 보다 무조건 1더 많게 건다. (무제한 배팅)
              elsif randomNumForBetting < 66 && randomNumForBetting >= 33       #랜덤 확률(33% 이상 66% 미만)
                this_bet = your_total_bet - my_total_bet + 2    #상대방이 건 배팅 보다 무조건 2더 많게 건다. (무제한 배팅)
              else  #랜덤 확률(66% 이상 100% 미만)
                this_bet = your_total_bet - my_total_bet + 3   #상대방이 건 배팅 보다 무조건 3더 많게 건다. (무제한 배팅)
              end

            else  # 내가 선공이므로 시작 배팅 (1,2,3 중 시작 배팅 랜덤 선택)
              if randomNumForBetting < 33
                this_bet = 1
              elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                this_bet = 2
              else
                this_bet = 3
              end
            end


          elsif win_percent >= 75 && win_percent < 99  ##상대 카드가 2일때
            maxbetting = 4
            if win_percent >= 94
              maxbetting = 7
            else (win_percent >= 85) && (win_percent < 94)
              maxbetting = 6
            end

            if your_total_bet > my_total_bet  # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting  # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1
              else    # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end

            else # 시작 배팅
              if my_total_bet == 1
                if randomNumForBetting < 33
                  this_bet = 1 # bet = 2
                elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                  this_bet = 2 # bet = 3
                else
                  this_bet = 3 # bet = 4
                end
              end
            end

          elsif win_percent >= 50 && win_percent < 75   ##상대 카드가 2일때
            maxbetting = 4

            if your_total_bet > my_total_bet  # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting  # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1
              else    # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end

            else # 시작 배팅
              if my_total_bet == 1
                if randomNumForBetting < 33
                  this_bet = 1 # bet = 2
                elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                  this_bet = 2 # bet = 3
                else
                  this_bet = 3 # bet = 4
                end
              end
            end

          elsif win_percent >= 28 && win_percent < 50   ##상대 카드가 2일때
            maxbetting = 2

            if your_total_bet > my_total_bet  # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting  # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1
              else    # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end

            else # 시작 배팅
              this_bet = 1
            end

          elsif win_percent < 28   ##상대 카드가 2일때
            maxbetting = 2

            if your_total_bet > my_total_bet  # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              if your_total_bet > maxbetting  # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
                this_bet = -1
              else    # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
                temp1 = (your_total_bet - my_total_bet)
                tmep2 = (maxbetting - my_total_bet)
                this_bet = rand(temp1..temp2)
              end

            else # 시작 배팅
              this_bet = 1
            end

          elsif opposite_play_card >= 8 #상대방 카드가 8이상이면 무조건 다이
            this_bet = -1

          else # 상대방의 카드가 5,6,7일때 1개는 배팅해본다.
            maxbetting = 2
            if your_total_bet > my_total_bet # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              this_bet = -1
            else # 시작 배팅
              this_bet = 1
            end
          end

        elsif (@@round == 3 || @@round == 4)
          ## 기초 로직

        elsif (@@round == 5 || @@round == 6)
          ## 7라운드 이후에는 데이터 기반 로직을 활용한다.
          #if

          #end
        elsif (@@round == 7 || @@round == 8)

        elsif @@round == 9
          if (win_percent > 98)
            if(your_total_bet > my_total_bet)
              if(your_total_bet - my_total_bet == my_money)
                this_bet = my_money
              elsif (your_total_bet == 60 - my_money - my_total_bet)
                this_bet = your_total_bet - my_total_bet
              else
                this_bet = your_total_bet - my_total_bet +1
              end
            else
              if(my_money < 3)
                this_bet = my_money
              else
                this_bet = 3
              end
            end
            # 3개 배팅 이후 상대방 추가금액 +1씩
          elsif(win_percent < 98 && win_percent > 65)
              if(your_total_bet > my_total_bet)
                if(maxbetting > your_total_bet)
                  this_bet = your_total_bet - my_total_bet
                else
                  this_bet = -1
                end
              else
                if(my_money < 2)
                  this_bet = my_money
                else
                  this_bet = 2
                end
              end
              # 2개 배팅 이후 맥스베팅 까지 콜
          else
            #다이
            this_bet = -1
          end

        elsif @@round == 10
          if(real_win_percent > 98)
           # 3개 배팅 이후 상대방추가금액 +1씩
           if(your_total_bet > my_total_bet)
             if(your_total_bet - my_total_bet == my_money)
               this_bet = my_money
             elsif (your_total_bet == 60 - my_money - my_total_bet)
               this_bet = your_total_bet - my_total_bet
             else
               this_bet = your_total_bet - my_total_bet +1
             end
           else
             if(my_money < 3)
               this_bet = my_money
             else
               this_bet = 3
             end
           end
         elsif(draw_percent > 98)
           if(your_total_bet > my_total_bet)
             this_bet = your_total_bet - my_total_bet
           else
             this_bet = 1
           end
           # 1개 배팅 이후 콜
         else(win_percent < 5)
           this_bet = -1
         end

        elsif @@round == 11

        elsif @@round == 12

        elsif @@round == 13

        elsif @@round == 14

        elsif @@round == 15

        elsif @@round == 16

        elsif @@round == 17

        elsif @@round == 18

        elsif @@round == 19
          if(my_money + my_total_bet == 32)
            if (win_percent > 98)
              if(your_total_bet > my_total_bet)
                this_bet = your_total_bet - my_total_bet
              else
                this_bet = 1
              end
              #1개배팅 이후 콜
            else
              #다이
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 31)
            if (win_percent > 98)
              if(your_total_bet > my_total_bet)
                this_bet = your_total_bet - my_total_bet
              else
                this_bet = 1
              end
              #1개배팅 이후 콜
            elsif(win_percent < 98 && win_percent > 65)
              #올인
              this_bet = 58 - my_money
            else
              #다이
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 30)
            if (win_percent > 98)
              if(your_total_bet > my_total_bet)
                this_bet = your_total_bet - my_total_bet
              else
                this_bet = 1
              end
              # 1개배팅 이후 콜
            elsif(win_percent < 98 && win_percent > 65)
              #올인
              this_bet = my_money
            else
              #다이
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 29)
            if (win_percent > 99)
              # 2개배팅 이후 콜
              if(your_total_bet > my_total_bet)
                this_bet = your_total_bet - my_total_bet
              else
                this_bet = 2
              end
            elsif(win_percent < 99 && win_percent > 65)
              # 2개배팅 이후 올인
              if(your_total_bet > my_total_bet)
                this_bet = my_money
              else
                this_bet = 2
              end
            else
              #올인
              this_bet = my_money
            end
          elsif(my_money + my_total_bet == 28)
            #무조건 올인
            this_bet = my_money
          else ##my_money + my_total_bet < 28  패배확실상황
            if(win_percent < 5)
              this_bet = -1
            else
              if(your_total_bet > my_total_bet)
                this_bet = your_total_bet - my_total_bet
              elsif(my_money < 15)
                this_bet = my_money
              else
                this_bet = 30 - my_money
              end
              #무승부 + 1개 배팅
            end
          end

        elsif @@round == 20
          if(my_money + my_total_bet == 31)
           if(win_percent > 95) ##무승부 혹은 승리일 경우
             #1개 배팅 이후 콜
             if(your_total_bet > my_total_bet)
               this_bet = your_total_bet - my_total_bet
             else
               this_bet = 1
             end
           else #패배
             #다이
             this_bet = -1
           end
         elsif(my_money + my_total_bet == 30)
           # 무조건 올인
           this_bet = my_money
         elsif(my_money + my_total_bet == 29)
           if(real_win_percent>98)
             if(your_total_bet > my_total_bet)
               this_bet = your_total_bet - my_total_bet
             else
               this_bet = 1
             end
             # 1개 배팅 이후 콜
           else  # 무승부 포함 패배일경우
             this_bet = my_money
             # 올인
           end
         else ## my_money + my_total_bet < 29 패배 확실
             #무승부갯수 + 1개 배팅 이후 콜
           if(your_total_bet > my_total_bet)
             this_bet = your_total_bet - my_total_bet
           elsif(my_money<15)
             this_bet = my_money
           else
             this_bet = this_bet = 30 - my_money
           end
         end
        end
      end


      ### 후공일때
      #### 후공인때는 상대방이 배팅을 하게되면 총 배팅이 나의 배팅보다 항상 크다.
      if (bet_history.count % 2) == 1
        if @@round == 1
          ## 기초 로직
          randomNumForBetting = rand(1..100)
          if opposite_play_card == 1 ##상대 카드가 1일때 = 무한
            if randomNumForBetting < 33 #랜덤 확률(33% 이하)
              this_bet = your_total_bet - my_total_bet + 1  #상대방이 건 배팅 보다 무조건 1더 많게 건다. (무제한 배팅)
            elsif randomNumForBetting < 66 && randomNumForBetting >= 33 #랜덤 확률(33% 이상 66% 미만)
              this_bet = your_total_bet - my_total_bet + 2 #상대방이 건 배팅 보다 무조건 2더 많게 건다. (무제한 배팅)
            else #랜덤 확률(66% 이상 100% 미만)
              this_bet = your_total_bet - my_total_bet + 3 #상대방이 건 배팅 보다 무조건 3더 많게 건다. (무제한 배팅)
            end


          elsif opposite_play_card == 2 ##상대 카드가 2일때
            maxbetting = 5
            if your_total_bet > maxbetting # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
              this_bet = -1
            else # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
              case your_total_bet
              when 2 then
                if randomNumForBetting < 25
                  this_bet = maxbetting - my_total_bet - 3 # call : bet = 2
                elsif randomNumForBetting < 50 && randomNumForBetting >= 25
                  this_bet = maxbetting - my_total_bet - 2 # bet = 3
                elsif randomNumForBetting < 75 && randomNumForBetting >= 50
                  this_bet = maxbetting - my_total_bet - 1 # bet = 4
                else
                  this_bet = maxbetting - my_total_bet # bet = 5
                end
              when 3 then
                if randomNumForBetting < 33
                  this_bet = maxbetting - my_total_bet - 2 # call : bet = 3
                elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                  this_bet = maxbetting - my_total_bet - 1 # bet = 4
                else
                  this_bet = maxbetting - my_total_bet # bet = 5
                end
              when 4 then
                if randomNumForBetting < 55
                  this_bet =  maxbetting - my_total_bet - 1 # call : bet = 4
                else
                  this_bet =  maxbetting - my_total_bet # bet = 5
                end
              when 5 then
                this_bet =  maxbetting - my_total_bet # call : bet = 5
              else
                this_bet = -1 # die
              end
            end

          elsif opposite_play_card == 3 ##상대 카드가 3일때
            maxbetting = 4
            if your_total_bet > maxbetting # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
              this_bet = -1 # die
            else # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
              case your_total_bet
              when 2 then
                if randomNumForBetting < 33
                  this_bet = maxbetting - my_total_bet -2 # call : bet = 2
                elsif randomNumForBetting < 66 && randomNumForBetting >= 33
                  this_bet = maxbetting - my_total_bet -1 # bet = 3
                else
                  this_bet = maxbetting - my_total_bet # bet = 4
                end
              when 3 then
                if randomNumForBetting < 50
                  this_bet = maxbetting - my_total_bet -1 # call : bet = 3
                else
                  this_bet = maxbetting - my_total_bet # bet = 4
                end
              when 4 then
                this_bet = maxbetting - my_total_bet # call : bet = 4
              else
                this_bet = -1 # die
              end
            end

          elsif opposite_play_card == 4
            maxbetting = 3
            if your_total_bet > maxbetting # 상대방의 총배팅이 최대 배팅보다 클때 = 다이
              this_bet = -1 # die
            else # 상대방의 총 배팅이 최대 배팅보다 낮을 경우 최대까지 남은 배팅을 한다.
              case your_total_bet
              when 2 then
                if randomNumForBetting < 50
                  this_bet = maxbetting - my_total_bet - 1 # call : bet = 2
                else
                  this_bet = maxbetting - my_total_bet # bet = 3
                end
              when 3 then
                  this_bet = maxbetting - my_total_bet # bet = 3
              else
                this_bet = -1 # die
              end
            end

          elsif opposite_play_card >= 8 #상대방 카드가 8이상이면 무조건 다이
            this_bet = -1

          else # 상대방의 카드가 5,6,7일때 1개는 배팅해본다.
            maxbetting = 2
            if your_total_bet > maxbetting # 상대방이 나의 배팅보다 더 많이 배팅 했을때
              this_bet = -1
            else # 후공이므로 콜
              this_bet = 1 # bet = 2
            end
          end


        elsif @@round == 2
          ## 기초 로직
          randomNumForBetting = rand(1..100)

        elsif (@@round == 3 || @@round == 4)
          ## 기초 로직

        elsif (@@round == 5 || @@round == 6)
          ## 7라운드 이후에는 데이터 기반 로직을 활용한다.
          #if

          #end
        elsif (@@round == 7 || @@round == 8)

        elsif @@round == 9
          if (win_percent > 98)
            if(your_total_bet - my_total_bet == my_money)
              this_bet = my_money
            elsif (your_total_bet == 60 - my_money - my_total_bet)
              this_bet = your_total_bet - my_total_bet
            else
              this_bet = your_total_bet - my_total_bet +1
            end
            # 상대방 추가금액 +1씩
          elsif(win_percent < 98 && win_percent > 65)
            if(maxbetting > your_total_bet)
              this_bet = maxbetting - my_total_bet
           else
             this_bet = -1
           end
            # 맥스베팅 까지 콜
          else
            #다이
            this_bet = -1
          end

        elsif @@round == 10
          if(real_win_percent > 98)
            # 받고 + 1
            if(your_total_bet - my_total_bet == my_money )
              this_bet = my_money
            elsif (your_total_bet == 60 - my_money - my_total_bet)
              this_bet = your_total_bet - my_total_bet
            else
              this_bet = your_total_bet - my_total_bet + 1
            end
          elsif(draw_percent > 98) #무승부
            this_bet = your_total_bet - my_total_bet
            # 콜
          else(win_percent < 5)
            this_bet = -1
          end
        elsif @@round == 11

        elsif @@round == 12

        elsif @@round == 13

        elsif @@round == 14

        elsif @@round == 15

        elsif @@round == 16

        elsif @@round == 17

        elsif @@round == 18

        elsif @@round == 19
          if(my_money + my_total_bet == 32)
             if (win_percent > 99)
              #올인
              this_bet = 58 - my_money
            else
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 31)
            if (win_percent > 99)
              #올인
              this_bet = 58 - my_money
            elsif(win_percent < 99 && win_percent > 65)
              #올인
              this_bet = 58 - my_money
            else
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 30)
            if (win_percent > 99)
              #받고+1
              if (your_total_bet == 30)
                this_bet = your_total_bet - my_total_bet
              else
              this_bet = your_total_bet - my_total_bet + 1
              end
            elsif(win_percent < 99 && win_percent > 65)
             #올인
             this_bet = my_money
            else
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 29)
            if (win_percent > 99)
              if your_total_bet - my_total_bet == my_money
                this_bet = my_money
              else
                this_bet = your_total_bet - my_total_bet + 1
              end
              #받고 +1
            elsif(win_percent < 99 && win_percent > 65)
              if your_total_bet - my_total_bet == my_money
                this_bet = my_money
              else
                this_bet = your_total_bet - my_total_bet + 1
              end
              #받고+1
            else
              #올인
              this_bet = my_money
            end
          elsif(my_money + my_total_bet == 28)
            this_bet = my_money
          else ##my_money + my_total_bet < 28  패배확실상황
            if(win_percent < 5)
              this_bet = -1
            else
              this_bet = my_money
            end
          end

        elsif @@round == 20
          if(my_money + my_total_bet == 31)
            if(win_percent > 95) ##무승부 혹은 승리일 경우
              # 콜
              this_bet = your_total_bet - my_total_bet
            else #패배
              #다이
              this_bet = -1
            end
          elsif(my_money + my_total_bet == 30)
            # 무조건 올인
            this_bet = my_money
          elsif(my_money + my_total_bet == 29)
            if(real_win_percent>98)
              this_bet = your_total_bet - my_total_bet
              # 콜
            else  # 무승부 포함 패배일경우
              this_bet = my_money
              # 올인
            end
          else ## my_money + my_total_bet < 29 패배 확실
            if (win_percent > 95)
              this_bet = my_money
            end
          end
        end
      end
    end

    if this_bet <= -1
      @@pMBet[@@round-1] = my_total_bet
    else
      @@pMBet[@@round-1] = my_total_bet + this_bet
    end
    # Return values
    ## 나의 배팅수, 이길 확률, 남은 카드 리스트, 상대패 대비 내가 이길수 있는 남은 카드의 수, 현재 라운드
    return this_bet, win_percent, left_card_list, can_win_to_enemy_card_count, @@round, @rival_card_history, @my_card_history, @@pRBet,  @@pMBet, @@MyCoinHistory, @@RivalCoinHistory, @@firstOrlast, eachround, maxindex,
    @@pMine, @@pRival, @rival_average_betting
  end


  def get_name
    "prc1 AI"
  end

  private
  def get_total_bet_money_per_person bet_history
    bet_history_object = bet_history.clone #Clone Object
    total_bet_money = [0, 0]
    index = 0
    while (bet_history_object.size > 0) do
      money = bet_history_object.pop
      total_bet_money[0] += money if index.even?
      total_bet_money[1] += money if index.odd?
      index += 1
    end
    total_bet_money
  end

end

s.add_handler("indian", MyAi.new)
s.serve
