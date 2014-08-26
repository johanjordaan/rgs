
tttController = ($scope,$timeout,Api) ->
  $scope.isBusy = ->
    $scope.busy

  isMatchReady = ->
    $scope.message = "Waiting for players..."
    Api.getMatchState { match_id:$scope.match_id }, (amatch) ->
      switch amatch.status
      | "inprogress" =>
        $scope.status = amatch.status
        pollServer!
      | otherwise =>
        $scope.status = amatch.status
        $timeout isMatchReady,1000

  updateBoard = (amatch) ->
    $scope.state_number = amatch.current_state.state_number
    $scope.role = amatch.role_map[$scope.player.match_key]
    $scope.moves = amatch.current_state.valid_moves[$scope.role]

    new_board = amatch.current_state._private.board
    for row to 2
      for col to 2
        cell = $scope.board[row][col]
        switch new_board[row][col]
        | 0 => cell.icon = ''
        | otherwise => cell.icon = new_board[row][col]

    #$scope.board = amatch.current_state._private.board

    $scope.selected_move = $scope.moves[0]

  pollServer = ->
    Api.getMatchState { match_id:$scope.match_id }, (amatch) ->
      switch
      | amatch.current_state.state_number > $scope.state_number =>
        updateBoard amatch
        if $scope.moves.length  == 1
          submitMove $scope.selected_move.id
          $scope.message = "Waiting for other players to move..."
        else
          $scope.message = "Submit your move"
      | otherwise =>
        $timeout pollServer,1000


  submitMove = (move_index)->
    move =
      state_number: $scope.state_number
      move_index: move_index

    Api.makeMove { match_id:$scope.match_id, match_key:$scope.player.match_key }, move
    .then (res) ->
      pollServer!
    .catch (err) ->
      pollServer!

  $scope.submit = ->
    submitMove $scope.selected_move.id

  $scope.play = ->
    Api.findMatches { game_id:'ttt', status:"waiting"},(matches) ->
      switch matches.length
      | 0 =>
        Api.startMatch { game_id:'ttt' }, (amatch) ->
          $scope.match_id = amatch.match_id
          $scope.status = amatch.status
          Api.joinMatch {match_id:amatch.match_id},$scope.player, (player_data) ->
            $scope.player.match_key = player_data.match_key
            $scope.busy = true

            isMatchReady!

      | otherwise =>
        Api.joinMatch { match_id:matches[0].match_id} ,$scope.player, (player_data) ->
          $scope.match_id = matches[0].match_id
          $scope.status = matches[0].status
          $scope.player.match_key = player_data.match_key
          $scope.busy = true

          pollServer!


  $scope.concede = ->
    $scope.busy = false

  startUp = ->
    $scope.busy = false
    $scope.player =
      name: ''
      match_key: ''
    $scope.match_id: ''
    $scope.status: ''
    $scope.message = ''
    $scope.state_number = -1
    $scope.board = []
    for row to 2
      $scope.board.push []
      for col to 2
        $scope.board[row].push do
          icon: ''


  startUp!


this.tttControllerSpec = ['$scope','$timeout','Api',tttController]
