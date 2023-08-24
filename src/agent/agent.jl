module Agent

using ..ChessBot

include("model.jl")
include("mcts.jl")
export Model
export mcts

end