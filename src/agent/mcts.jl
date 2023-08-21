mutable struct Node
    state::ChessState
    value::Int
    visits::Int
    actions::Vector{Int16}
    explorable_actions::Vector{Bool}
    children::Vector{Node}
    parent
    action_index::Int

    function Node(state::ChessState)
        Node(state, nothing, 0)
    end

    function Node(state::ChessState, parent, action_index)
        actions = Chess.get_actions(state)
        explorable_actions = [true for _ in actions]
        new(state, 0, 0, actions, explorable_actions, [], parent, action_index)
    end
end

function Base.show(io::IO, node::Node)
    println(io, node.state.board)
end

function is_fully_expanded(node)
    length(node.actions) == length(node.children) && 
    length(node.actions) > 0
end

function select(node)
    best_child = Nothing
    best_ucb = -Inf32

    for child in node.children
        ucb = get_ucb(child, node.visits)
        if ucb > best_ucb
            best_child = child
            best_ucb = ucb
        end
    end

    best_child
end

function get_ucb(node, parent_visits, c=1.41421356237)
    q_value = ((node.value / node.visits) + 1) / 2
    (1 - q_value) + c * sqrt(log(parent_visits) / node.visits)
end

function get_score_and_terminated(node)
    Chess.get_score_and_terminated(node.state)
end

function expand(node)
    action_index = rand(findall(node.explorable_actions))
    node.explorable_actions[action_index] = false
    action = node.actions[action_index]
    new_state = Chess.step(node.state, action)
    child = Node(new_state, node, action_index)
    push!(node.children, child)
    child
end

function simulate(node)
    opponent_multiplier = 1
    state = node.state
    score, terminated = Chess.get_score_and_terminated(state)
    while !terminated
        action = rand(Chess.get_actions(state))
        state = Chess.step(state, action)
        score, terminated = Chess.get_score_and_terminated(state)
        opponent_multiplier *= -1
    end
    score * opponent_multiplier
end

function back_propogate(node, score)
    opponent_multiplier = 1
    while node !== nothing
        node.value += score * opponent_multiplier
        node.visits += 1
        node = node.parent
        opponent_multiplier *= -1
    end
end

function mcts(state::ChessState, num_searches::Int)
    root = Node(state)
    for _ in 1:num_searches
        node = root

        # Select
        while is_fully_expanded(node)
            node = select(node)
        end

        # Expand
        score, terminated = get_score_and_terminated(node)

        # Simulate
        if !terminated
            node = expand(node)
            score = simulate(node)
        end

        # Backpropogate
        back_propogate(node, score)
    end

    # return root
    probs = zeros(Float16, length(root.actions))
    for child in root.children
        probs[child.action_index] = child.visits
    end
    probs ./= sum(probs)
    return probs
end