rgs
===

rest game service

rest interface
match -> open, waiting, inprogress, done and (aborted)


Error codes
====================
200 OK
400 Invalid parameters
404 Not Found
500 Fatal error

Game states
====================
waiting - The game has been started and is currently waiting for players to join
inprogress - The game is in progress
done - The game is done


Bot developers
====================



game developers
=====================
Your game needs to provide two methods

initial_game_state : options -> game_state
next_game_state : game_state * moves -> game_state

TODO: ranking: game_state.results * [player.rank] -> [player:new_rank]  

options is a dictionary of values that you can use to construct your game state
game state is a dictionary of values

    roles: [role_1 role2 ... role_n]
    finished: true/false
    results: { role_1:score role_2:score ... role_n:score   }
    game_state.valid_moves : { role_1:[moves] role_2:[moves] ... role_n:[moves]   }
    _private: { ... }
