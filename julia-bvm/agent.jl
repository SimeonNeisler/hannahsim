export Opinion, Agent, getOpinions, setOpinion
@enum Opinion Red Blue
mutable struct Agent
    opinion_array::Array{Opinion, 1}
    Agent(o::Opinion) = new(Array{Opinion, 1}([rand((Red::Opinion, Blue::Opinion))]))
    Agent() = new(Array{Opinion, 1}([rand((Red::Opinion, Blue::Opinion)), rand((Red::Opinion, Blue::Opinion))]))
end

function getOpinions(agent::Agent)
    return agent.opinion_array
end

function setOpinion(agent::Agent, newopinion::Opinion, opinion_num::Int)
    agent.opinion_array[opinion_num] = newopinion
end

function isConsistent(agent::Agent)
    return all(agent.opinion_array[i] == agent.opinion_array[1]
        for i in 1:length(agent.opinion_array))
end
