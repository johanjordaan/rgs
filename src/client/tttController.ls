var timer

tttController = ($scope,$timeout,Api) ->
  $scope.isBusy = ->
    $scope.busy

  updateBoard = (amatch) ->
    new_board = amatch.current_state._private.board
    moves = amatch.current_state.valid_moves[$scope.role]
    for row to 2
      for col to 2
        cell = $scope.board[row][col]
        switch new_board[row][col]
        | 0 =>
          cell.icon = ''
          cell.move_index = moves |> _.find-index (move) ->
            move.row == row and move.col == col
        | otherwise => cell.icon = new_board[row][col]

  setTimer = ->
    clearTimer!
    timer := $timeout pollServer,1000

  clearTimer = ->
    if timer?
      $timeout.cancel timer


  pollServer = ->
    Api.getMatchState { match_id:$scope.match_id,match_key:$scope.player.match_key }, (amatch) ->
      $scope.status = amatch.status
      $scope.state_number = amatch.current_state?.state_number
      $scope.role = amatch.role_map?[$scope.player.match_key]
      $scope.moves = amatch.current_state.valid_moves?[$scope.role]

      switch $scope.status
      | "waiting" =>
        $scope.message = "Waiting for players to join ..."
        setTimer!
      | "inprogress" =>
        switch
        | !amatch.submitted_moves?[$scope.role]? =>
          updateBoard amatch
          if $scope.moves.length  == 1
            # TODO : there should be a NOP move in all games.... that can be done automatically
            submitMove $scope.moves[0].id
            $scope.message = "Waiting for other players to move..."
          else
            $scope.message = "Submit your move"
            # Let the server know we are alive?
          setTimer!
        | otherwise =>
          $scope.message = "Waiting for other players to move..."
          setTimer!
      | otherwise =>
        updateBoard amatch
        switch amatch.current_state.results[$scope.role]
        | 3 => $scope.message = "Done ... You won!"
        | 1 => $scope.message = "Done ... It was a draw"
        | otherwise => $scope.message = "Done ... You lost :("
        clearTimer!


  submitMove = (move_index)->
    move =
      state_number: $scope.state_number
      move_index: move_index

    if !$scope.moves[move_index].nop
      row = $scope.moves[move_index].row
      col = $scope.moves[move_index].col
      $scope.board[row][col] = do
        icon:$scope.role
        move_index:-1

    Api.makeMove { match_id:$scope.match_id, match_key:$scope.player.match_key }, move
    .then (res) ->
      pollServer!
    .catch (err) ->
      pollServer!

  $scope.submit = (move_index) ->
    switch move_index
    | -1 =>
    | otherwise => submitMove move_index

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

            pollServer!

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
          move_index: -1


  startUp!

_  = require 'prelude-ls'
this.tttControllerSpec = ['$scope','$timeout','Api',tttController]
