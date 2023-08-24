using Dates
using Distributions

include("../src/ChessBot.jl")
using .ChessBot


function simulate()
    state::ChessState = Chess.starting_state()
    terminated = false
    score = 0
    while !terminated
        action = if Chess.is_white_turn(state)
            probs = mcts(model, state, 100)
            action = rand(Categorical(probs))
        else
            rand(Chess.get_actions(state))
        end
        state = Chess.step(state, action)
        score, terminated = Chess.get_score_and_terminated(state)
    end

    if !Chess.is_white_turn(state)
        score *= -1
    end
    if score == 1
        println("Win")
        return [1, 0, 0], state.board.full_move
    elseif score == -1
        println("Loss")
        return [0, 0, 1], state.board.full_move
    else
        println("Draw")
        return [0, 1, 0], state.board.full_move
    end
end

model = Model()

num_samples = 100
start_time = now()
results = [0,0,0]
num_moves = 0
for i in 1:num_samples
    print("#", i, ", ")
    r, n = simulate()
    global results .+= r
    global num_moves += n
end
println("Finished in ", now()-start_time)
wins, draws, losses = results
println("Wins: ", wins, ", Draws: ", draws, ", Losses: ", losses)
println("Average game length: ", num_moves/num_samples)