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

  @@record_of_Rival_predict=[]  # 상대방이 내 카드를 보고 예측한 승률(p)에 따른 배팅 기록을 정리
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


    ## 코인 갯수 차이
    ### 코인 갯수 차이 계산 (a+b = 58 <=> b = 58-a <=> a-b = a-(58-a) = 2a-58)
    current_round_coin_gap = (my_money * 2) - 58
    ### 현재 라운드의 코인 갯수 차이가 남은 라운드 수의 두 배가 넘을 경우 무조건 승리
    if current_round_coin_gap > ((21 - @@round)*2)
      victory = true
    end

    youngil = 0


    ## 확률 계싼
    ### 상대방 패보다 내 패가 좋을 때 카드 개수(+ 안 좋을때 카드 개수)
    can_win_to_enemy_card_count = left_card_list.count { |left_each_card_number| left_each_card_number >= opposite_play_card }
    can_lose_to_enemy_card_count = left_card_list.count - can_win_to_enemy_card_count

    ### 상대방 패를 이길 혹률 (+ 질 확률)
    win_percant = (can_win_to_enemy_card_count.to_f / left_card_list.count.to_f) * 100.0
    lose_percent = 100.0 - win_percant

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
    ### 총 20라운드(남은 라운드로 계산 하면 19 ~ 0 이다)를 4라운드씩 19~16 | 15~12 | 11~8 | 7 ~ 4| 4그룹과 3,2,1,0인 특수 라운드로 나눈다.
    ### 19 ~ 16 그룹 = 승리 확률이 60% 이상일때 배팅을 하지만 배팅의 상한선을 60% = 1 |70% =  2 | 80% = 3 | 90% = 4 | 100% =무한 으로 한다. - 초반에 안전 위주 전략
    ### 15 ~ 12 그룹 = 승리 확률이 50% 이상일때 배팅을 하지만 배팅의 상한선을 50% = 1 | 60% = 2 |70% =  3 | 80% = 3 | 90% = 4 | 100% =무한 으로 한다. - 조금씩 뺴먹는 전략
    ### 11 ~ 8 그룹 = 승리 확률이 40% 이상일때 배팅을 하지만 배팅의 상한선을 40% = 1 | 50% = 2 | 60% = 3 |70% =  3 | 80% = 4 | 90% = 4 | 100% =무한 으로 한다. - 위험을 감수한 전략
    #### 7라운드 이하로 경기가 남았을때는 상대와 나의 코인 갭차이를 잘 활용하여야 한다.
    ### 7 ~ 4 그룹
    #### A. 갭차이가 많이 앞서고 있다면 확실한 안전 = 승리 확률이 85% 이상일때만 승부를 건다 - 안전 주의
    #### B. 비등비등 할때 = 승리 확률이 60% 이상일때 배팅을 하지만 배팅의 상한선을 60% = 1 |70% =  2 | 80% = 5 | 90% = 5 | 100% = 무한 으로 한다. - 낄낄빠빠 전략
    #### C. 우리가 지고 있을때 = 승리 확률이 55% 이상이면 배팅을 건다. 55% = 1 | 70% = 3 | 80% = 5 | 90% = 7 | 100% 무한 - 조금이라도 코인 얻기
    ### 3,2,1,0일때 혀재 코인 상황에 맞게 배팅한다.
    #### A. 갭 차이가 많이 앞설떄 = 70% = 1 | 80% = 2 | 90% = 3 | 100% = 무한 - 높은 승률일떄도 조금따고 적을떄도 적게 읽는 전략
    #### B. 비등비등 할때 = 60% = 2 | 70% = 3 | 80% = 4 | 90% = 5 | 100% = 무한 - 한번의 승부로 갭을 높이는 전략
    #### C. 조금 지고있을때 승률이 60%이상일때 최소 5개이상씩 배팅을 진행한다.
    #### D. 조금 많이있을때 승률이 60%이상일때 최소 5개이상씩 배팅을 진행한다. + 승률이 50%이상일 때 블러핑을 한다.

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


    ## 배팅 방법
    ### 선공일때
    if (bet_history.count % 2) == 0
      #### round 수에 따른 다양한 패턴
      # random_number = Random.new
      # case_number = (20 - @@round) / 4 #남은 라운드 수에 따라 케이스 분류(19~16 | 15~12 | 11~8 | 7 ~ 4| 3,2,1,0)
      # bluffing = random_number.rand(100)
      # case case_number
      # when 4 then
      #     if win_percant == 100 ## 배팅 로직에 대해서 계산 필요.
      #       if (60 - your_total_bet - my_total_bet - my_money) < my_money
      #         this_bet = 60 - your_total_bet - my_total_bet - my_money
      #       this_bet = bet_history.last + 2
      #     elsif win_percant > 90
      #
      #     elsif win_percant > 80
      #
      #     elsif win_percant > 70
      #       if(bluffing <= 10)
      #
      #       else
      #
      #       end
      #     elsif win_percant > 60
      #       if(bluffing <= 10)
      #
      #       else
      #
      #       end
      #     else
      #       if(bluffing <= 10)
      #
      #       else
      #
      #       end
      #     end
      #
      # when 3 then
      #
      # when 2 then
      #
      # when 1 then
      #
      # else ##4라운드 미만(= 3,2,1,0 라운드) 남았을때
      #
      # end
    end

    ### 후공일때
    if (bet_history.count % 2) == 0
      # case_number = (20 - @@round) / 4 #남은 라운드 수에 따라 케이스 분류(19~16 | 15~12 | 11~8 | 7 ~ 4| 3,2,1,0)
      # case case_number
      # when 4 then
      #
      # when 3 then
      #
      # when 2 then
      #
      # when 1 then
      #
      # else ##4라운드 미만(= 3,2,1,0 라운드) 남았을때
      #
      # end
    end


    # Return values
    ## 나의 배팅수, 이길 확률, 남은 카드 리스트, 상대패 대비 내가 이길수 있는 남은 카드의 수, 현재 라운드
    return this_bet, win_percant, left_card_list, can_win_to_enemy_card_count, @@round, @@pRival, @@pMine, @@pRBet, @@pMBet, @@MyCoinHistory, @@RivalCoinHistory


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
