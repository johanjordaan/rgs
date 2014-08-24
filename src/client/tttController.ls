
tttController = ($scope,$timeout,Api) ->
  $scope.isBusy = ->
    $scope.busy


  isMatchReady = ->
    Api.getMatchState { match_id:$scope.match_id }, (amatch) ->
      switch amatch.status
      | "inprogress" =>
        $scope.status = amatch.status
      | otherwise =>
        $scope.status = amatch.status
        $timeout isMatchReady,1000




  $scope.play = ->
    # 1) Look for a game to join
    # 2) If ther is one then join it
    # 3) else create one and join it
    Api.findMatches { game_id:'ttt', status:"waiting"},(matches) ->
      switch matches.length
      | 0 =>
        Api.startMatch { game_id:'ttt' }, (amatch) ->
          $scope.match_id = amatch.match_id
          $scope.status = amatch.status
          Api.joinMatch {match_id:amatch.match_id},$scope.player, (player_data) ->
            $scope.player.match_key = player_data.match_key
            $scope.busy = true

            $timeout isMatchReady,1000

      | otherwise =>
        Api.joinMatch { match_id:matches[0].match_id} ,$scope.player, (player_data) ->
          $scope.match_id = matches[0].match_id
          $scope.status = matches[0].status
          $scope.player.match_key = player_data.match_key
          $scope.busy = true

          Api.getMatchState { match_id:$scope.match_id }, (amatch) ->
            $scope.status = amatch.status

            Api.makeMove { match_id:$scope.match_id }, {}, (amatch) ->
              




  $scope.concede = ->
    $scope.busy = false

  startUp = ->
    $scope.busy = false
    $scope.player =
      name: ''
      match_key: ''
    $scope.match_id: ''
    $scope.status: ''

  startUp!




  clear = ->
    $scope.status = "Idle..."
    $scope.playerA = {name:'bob'}
    $scope.playerB = {name:'sue'}
    $scope.match_id = ""
    $scope.state_number = 0

  clear!



this.tttControllerSpec = ['$scope','$timeout','Api',tttController]
