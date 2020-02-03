export Opinion, Agent, getOpinion, setOpinion
@enum Opinion Red Blue
mutable struct Agent
    opinion::Opinion
    Agent(opinion::Opinion) = new(opinion::Opinion)
end

function getOpinion(agent::Agent)
    return agent.opinion
end
function setOpinion(agent::Agent, newOpinion::Opinion)
    agent.opinion = newOpinion
end
