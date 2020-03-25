export Opinion, Agent, getOpinions, setOpinion
@enum Opinion Red Blue
mutable struct Agent
    opinion_array::Array{Opinion, 1}
    Agent() = new(Array{Opinion, 1}([Red, Red]))
end

function getOpinions(agent::Agent)
    return agent.opinion_array
end

function setOpinion(agent::Agent, newopinion::Opinion, opinion_num::Int)
    agent.opinion_array[opinion_num] = newopinion
end
