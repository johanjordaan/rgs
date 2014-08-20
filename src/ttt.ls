_ = require 'prelude-ls'
utils = require './utils'

initial_board = ->
  board = [
    [0 0 0]
    [0 0 0]
    [0 0 0]
  ]

copy_board = (source_board) ->
  new_board = []
  for row to 2
    new_board.push []
    for col to 2
      new_board[row].push source_board[row][col]

  new_board

copy_game_state = (source_game_state)->
  new_game_state =
    roles: source_game_state.roles
    finished: source_game_state.finished
    valid_moves: get_valid_moves source_game_state
    state_number: source_game_state.state_number
    results:
      X: source_game_state.results.X
      O: source_game_state.results.O
    _private:
      board: copy_board source_game_state._private.board
      active_role: source_game_state._private.active_role

  new_game_state

# Returns a structure with the valid moves for each role
# { role:[moves ...], ...  }
get_valid_moves = (game_state) ->
  # Initialise the moves to NOP(ie do nothing), in the case of ttt it would be invalid to
  # be active and not make a move so this will be remomved later
  #
  moves_for_role =
    X: [{id:0,nop:true,description:"Do nothing"}]
    O: [{id:0,nop:true,description:"Do nothing"}]

  if !game_state.finished
    moves_for_role[game_state._private.active_role] = []

    id = 0
    for row to 2
      for col to 2
        switch game_state._private.board[row][col]
        | 0 => moves_for_role[game_state._private.active_role].push do
            id:id++
            row:row
            col:col
            description:"#{game_state._private.active_role} to row #{row} col #{col}"
        | otherwise =>

  moves_for_role

# This updates the game_state ... Side effecty ... Can this be done better?
#
calculate_results = (game_state) ->
  winner = 0
  board = game_state._private.board
  for i to 2
    if board[i][0] == board[i][1] == board[i][2]
      winner = board[i][0]
    if board[0][i] == board[1][i] == board[2][i]
      winner = board[0][i]

  if board[0][0] == board[1][1] == board[2][2]
    winner = board[0][0]
  if board[0][2] == board[1][1] == board[2][0]
    winner = board[0][2]

  switch winner
  | 0 =>
    switch (board |> _.flatten |> _.any (item) -> item == 0)
    | true => game_state.finished = false
    | otherwise =>
      game_state.finished = true
      game_state.results.X = 1
      game_state.results.O = 1
  | otherwise =>
    game_state.finished = true
    game_state.results[winner] = 3

  game_state

# As input to this a list of match_key entries are passed. These represent the players
# the players will be allocated to the roles in the game state
# Players : [ of match keys]
#
initial_game_state = ->
  roles = ['X','O']
  active_role = roles[0]

  game_state =
    roles: roles
    finished: false
    state_number: 0
    results:
      X: 0
      O: 0
    _private:
      board: initial_board!
      active_role: active_role

  game_state.valid_moves = get_valid_moves game_state

  game_state


# Return a next game state after the move has been applied
# moves is an object with the roles as keys and the move index
# as the value. We can assume that moves will always be valid.
# The harnass will make sure that random moves are selected
# if the user is tardy.
#
next_game_state = (game_state, moves) ->
  new_game_state = copy_game_state game_state
  active_role = game_state._private.active_role

  move = game_state.valid_moves[active_role][moves[active_role]]
  new_game_state._private.board[move.row][move.col] = active_role

  switch active_role
  | 'X' => new_game_state._private.active_role = 'O'
  | otherwise => new_game_state._private.active_role = 'X'

  calculate_results new_game_state
  new_game_state.valid_moves = get_valid_moves new_game_state

  new_game_state.state_number = new_game_state.state_number + 1

  new_game_state


if module?
  module.exports =
    initial_game_state: initial_game_state
    next_game_state: next_game_state
