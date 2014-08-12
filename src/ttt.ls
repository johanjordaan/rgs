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
  # Stuff that needs to be copied between game states
  #
  new_game_state =
    board: copy_board source_game_state.board
    result:
      finished: source_game_state.result.finished
      scores:
        X: source_game_state.result.scores.X
        O: source_game_state.result.scores.O

  # Stuff thats ok to reference.(ie does not need to be copied)
  #
  new_game_state.roles = source_game_state.roles
  new_game_state.role_map =  source_game_state.role_map
  new_game_state.active_role = source_game_state.active_role

  new_game_state

# Returns a structure with the valid moves for each role
# { role:[moves ...], ...  }
get_valid_moves = (game_state) ->
  moves_for_role =
    X: []
    O: []

  for row to 2
    for col to 2
      switch game_state.board[row][col]
      | 0 => moves_for_role[game_state.active_role].push do
        row:row
        col:col
        description:"#{game_state.active_role} to row #{row} col #{col}"
      | otherwise =>

  moves_for_role

# This updates the game_state ... Side effecty ... Can this be done better?
#
calculate_results = (game_state) ->
  winner = 0
  for i to 2
    if game_state.board[i][0] == game_state.board[i][1] == game_state.board[i][2]
      winner = game_state.board[i][0]
    if game_state.board[0][i] == game_state.board[1][i] == game_state.board[2][i]
      winner = game_state.board[0][i]

  if game_state.board[0][0] == game_state.board[1][1] == game_state.board[2][2]
    winner = game_state.board[0][0]
  if game_state.board[0][2] == game_state.board[1][1] == game_state.board[2][0]
    winner = game_state.board[0][2]

  switch winner
  | 0 =>
    switch (game_state.board |> _.flatten |> _.any (item) -> item == 0)
    | true => game_state.result.finished = false
    | otherwise =>
      game_state.result.finished = true
      game_state.result.scores.X = 1
      game_state.result.scores.O = 1
  | otherwise =>
    game_state.result.finished = true
    game_state.result.scores[winner] = 3

  game_state

# Applies the move to the game_state and return a new game state
apply_move = (game_state, move) ->
  new_game_state = copy_game_state game_state

  new_game_state.board[move.row][move.col] = game_state.active_role
  switch game_state.active_role
  | 'X' => new_game_state.active_role = 'O'
  | otherwise => new_game_state.active_role = 'X'

  new_game_state.valid_moves = get_valid_moves new_game_state

  calculate_results new_game_state

  new_game_state


# As input to this a list of match_key entries are passed. These represent the players
# the players will be allocated to the roles in the game state
# Players : [ of match keys]
#
initial_game_state = (number_of_players) ->
  roles = ['X','O']
  active_role = roles[0]

  game_state =
    board: initial_board!
    roles: roles
    active_role: active_role
    result:
      finished: false
      scores:
        X: 0
        O: 0

  game_state.valid_moves = get_valid_moves game_state

  game_state


# Return a next game state after the move has been applied
#
next_game_state = (game_state, role, move_index) ->
  move = game_state.valid_moves[role][move_index]
  new_game_state = apply_move game_state, move

if module?
  module.exports =
    initial_game_state: initial_game_state
    get_valid_moves: get_valid_moves
    next_game_state: next_game_state
