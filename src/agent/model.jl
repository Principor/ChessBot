using Flux
using CUDA

device = if CUDA.functional()
    gpu
else
    cpu
end

struct Model
    base::Chain
    policy::Chain
    value::Dense
end
Flux.@functor Model

function Model()
    base = Chain(
        Flux.flatten,
        Dense(12*64 => 1024, relu),
        Dense(1024 => 1024, relu),
    )
    policy = Chain(
        Dense(1024 => 4096),
        softmax
    )
    value = Dense(1024 => 1, tanh)
    Model(base, policy, value) |> device
end

function (model::Model)(x, action_mask)
    base = model.base(x)
    policy = model.policy(base)
    policy .*= action_mask
    policy ./= sum(policy)
    value = model.value(base)
    policy, value
end