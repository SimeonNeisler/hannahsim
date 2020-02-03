mutable struct Agent
    @enum Opinion Red Blue
    Agent(Opinion::Opinion) = new(Opinion::Opinion)
end

function getOpinion(agent::Agent)
    return agent.Opinion
end
function setOpinion(agent::Agent, newOpinion::Opinion)
    agent.Opinion = newOpinion
end
