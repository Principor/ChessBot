mutable struct Node
    state::ChessState
    value::Float32
    visits::Int
    actions::Vector{Int16}
    children::Vector{Node}
    parent
    chosen_action::Int
    prob::Float32

    function Node(state::ChessState)
        Node(state, nothing, 0, 0)
    end

    function Node(state::ChessState, parent, chosen_action, prob)
        actions = Chess.get_actions(state)
        new(state, 0, 0, actions, [], parent, chosen_action, prob)
    end
end

function Base.show(io::IO, node::Node)
    println(io, node.state.board)
end

function is_expanded(node)
    length(node.children) != 0
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

function get_ucb(node, parent_visits, c=2)
    q_value = if node.visits == 0
        1 / 2
    else
        1 - (1 + node.value / node.visits) / 2
    end
    q_value + c * (sqrt(parent_visits) / (node.visits + 1)) * node.prob
end

function get_score_and_terminated(node)
    Chess.get_score_and_terminated(node.state)
end

function expand(node, policy)
    for action in node.actions
        new_state = Chess.step(node.state, action)
        child = Node(new_state, node, action, policy[action])
        push!(node.children, child)
    end
end

function back_propogate(node, value)
    opponent_multiplier = 1
    while node !== nothing
        node.value += value * opponent_multiplier
        node.visits += 1
        node = node.parent
        opponent_multiplier *= -1
    end
end

function mcts(model::Model, state::ChessState, num_searches::Int)
    root = Node(state)
    for _ in 1:num_searches
        node = root

        # Select
        while is_expanded(node)
            node = select(node)
        end

        # Expand
        value, terminated = get_score_and_terminated(node)

        # Simulate
        if !terminated
            encoded = Chess.get_encoded_state(node.state)
            encoded = reshape(encoded, size(encoded)..., 1)
            mask = zeros(Float32, 4096)
            for action in node.actions
                mask[action] = true
            end

            policy, value = model(encoded |> device, mask |> device) |> cpu
            value = value[1]

            expand(node, policy)
        end

        # Backpropogate
        back_propogate(node, value)
    end

    # return root
    probs = zeros(4096)
    for child in root.children
        probs[child.chosen_action] = child.visits
    end
    probs ./= max(1, sum(probs))
    return probs
end