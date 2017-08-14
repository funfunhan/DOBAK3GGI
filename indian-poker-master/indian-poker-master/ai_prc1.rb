require "xmlrpc/server"
require "socket"

s = XMLRPC::Server.new(ARGV[0])
MIN_DEFAULT_BET = 1

class MyAi
  @@pRival=[] # 지금까지의 상대의 패
  @@pMine=[]  # 지금까지의 나의 패
  @@pRBet=[]  # 지금까지의 상대의 베팅 기록
  @@pMBet=[]  # 지금까지의 나의 베팅 기록
  @@MyCoinHistory = []
  @@RivalCoinHistory = []


  @@record_of_Rival_predict=[]  # 상대방이 내 카드를 보고 예측한 승률(p)에 따른 첫 배팅 기록을 정리
                                # 0 - 0% <= p < 20%
                                # 1 - 20% <= p < 40%
                                # 2 - 40% <= p < 60%
                                # 3 - 60% <= p < 80%
                                # 4 - 80% <= p < 100%
                                # 5 - p == 100%
                                ## 각 원소는 배열로 이루어져 있으며(2차원 배열), 0번째 인덱스는 현재 확률모델 수치의 가용 여부를 표시하는 스위치이다.
                                ## ex) @@record_of_Rival_predic[1][0] == true 이면 20% <= p < 40% 사이의 추측확률에 대해 신용할 수 있다.




  @@round = 0
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
    ##턴이 시작되면 round 1씩 올림
    if (bet_history.count / 2) == 1
      @@round = @@round +1
      @@MyCoinHistory.push(my_money+1)
      @@RivalCoinHistory.push(60-(my_money+1))
      if @@round != 1
        @@pRBet.push((@@RivalCoinHistory[@@round-1] - @@RivalCoinHistory[@@round-2]).abs)
        @@pMBet.push((@@MyCoinHistory[@@round-1] - @@MyCoinHistory[@@round-2]).abs)
      end
      @@pRival.push(opposite_play_card)
    end

    if @@round != 1 && @@round != 11
      if past_cards.last == @@pRival[@@pRival.length - 2]
        @@pMine.push(past_cards[past_cards.length - 2])
      else
        @@pMine.push(past_cards.last)
      end
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
    can_lose_to_enemy_card_count = left_card_list.count - can_win_to_enemy_card_count

    ### 상대방 패를 이길 혹률 (+ 질 확률)
    win_percent = (can_win_to_enemy_card_count.to_f / left_card_list.count.to_f) * 100.0
    lose_percent = 100.0 - win_percent

    ## 라운드가 10일떄는 상대방의 패와 나의 패 모두 알 수 있으므로 바로 저장
    if @@round == 10
      @@pMine.push(left_card_list.last)
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
    current_round_coin_gap = (my_money * 2) - 58
    ### 현재 라운드의 코인 갯수 차이가 남은 라운드 수의 두 배가 넘을 경우 무조건 승리


    testinput = 0


    stability = ((current_round_coin_gap.to_f) / ((21 - @@round).to_f))
    # stablity는 안정도로 2보다 큰 경우에 무조건 이김 (2면 비김)
    if stability > 2
      victory = true
    end

    ## stability가 정확히 2인 경우, 확실히 승리하는 조건이 아니면 웬만해선 다이를 선택하도록 한다.
    ## 그러나 남은 게임 수가 적은 경우, 매우 유력한 상황에서 베팅을 한다.


    # 변칙로직 2 - 그룹별 승리 확률 계산 및 적용
    ##



    # 변칙로직 3 - 랜덤 변수 활용
    ## 랜덤변수 선언



    # 변칙로직 4 - 상대방 배팅에 대해서 분석 후 추가 배팅 로직 설정
    ## 배팅 로직 설정


    ## 배팅 방법
    ### 선공일때
    if (bet_history.count % 2) == 0
        if (@@round == 1 || @@round == 11)
          ## 기초 로직
          if opposite_play_card == 1

          elsif opposite_play_card == 2
            my_total_bet <= 5
          elsif opposite_play_card == 3
            my_total_bet <= 4
          elsif opposite_play_card == 4
            my_total_bet <= 3
          elsif opposite_play_card == 5
            my_total_bet <= 2
          else
            this_bet == -1
          end

          ## 데이터 기반 로직
          if @@round == 11

          end

        elsif ((@@round == 2 || @@round == 3) || (@@round == 12 || @@round == 13))
          ## 기초 로직

          ## 데이터 기반 로직
          if @@round == 12 || @@round == 13

          end

        elsif((@@round >= 4 && @@round <= 6) || (@@round >= 14 && @@round <= 16))
          ## 기초 로직

          ## 데이터 기반 로직
          if @@round >= 14 && @@round <= 16

          end

        elsif ((@@round == 7 || @@round == 8) || (@@round == 17 || @@round == 18))
          ## 7라운드 이후에는 데이터 기반 로직을 활용한다.
          #if

          #end

        elsif (@@round == 9 || @@round == 19)
          ## 9, 19라운드는 특별한 상황에 대한 로직 설정

        else ## @@round == 10 or 20

        end
    end

    ### 후공일때
    if (bet_history.count % 2) == 0
      if (@@round == 1 || @@round == 11)
        ## 기초 로직

        ## 데이터 기반 로직
        if @@round == 11

        end

      elsif ((@@round == 2 || @@round == 3) || (@@round == 12 || @@round == 13))
        ## 기초 로직

        ## 데이터 기반 로직
        if @@round == 12 || @@round == 13

        end

      elsif((@@round >= 4 && @@round <= 6) || (@@round >= 14 && @@round <= 16))
        ## 기초 로직

        ## 데이터 기반 로직
        if @@round >= 14 && @@round <= 16

        end

      elsif ((@@round == 7 || @@round == 8) || (@@round == 17 || @@round == 18))
        ## 7라운드 이후에는 데이터 기반 로직을 활용한다.
        #if

        #end

      elsif (@@round == 9)

      elsif (@@round == 19)
        if(my_money == 32)
          if (win_percent > 99)
            #올인
          else
            #다이
          end
        elsif(my_money == 31)
          if (win_percent > 99)
            #올인
          elsif(win_percent < 99 && win_percent > 65)
            #올인
          else
            #다이
          end
        elsif(my_money == 30)
          if (win_percent > 99)
            #받고+1
          elsif(win_percent < 99 && win_percent > 65)
            #올인
          else
            #다이
          end
        elsif(my_money == 29)
          if (win_percent > 99)
            #받고+1
          elsif(win_percent < 99 && win_percent > 65)
            #받고+1
          else
            #올인
          end
        elsif(my_money == 28)
        else ##my_money < 28  패배확실상황
          if(win_percent < 5)
            #다이
          else
            #무승부 + 1개 배팅
          end


        ## 9, 19라운드는 특별한 상황에 대한 로직 설정

      elsif(@@round == 10) ## @@round == 10

      else ## @@round == 20

      end
    end


    # Return values
    ## 나의 배팅수, 이길 확률, 남은 카드 리스트, 상대패 대비 내가 이길수 있는 남은 카드의 수, 현재 라운드
    return this_bet, win_percent, left_card_list, can_win_to_enemy_card_count, @@round, @@pRival, @@pMine, @@pRBet, @@pMBet, @@MyCoinHistory, @@RivalCoinHistory


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
