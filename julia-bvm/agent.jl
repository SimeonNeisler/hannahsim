mutable struct Agent
    opinion::String
    Agent(opinion) = new(opinion)
end

function getOpinion(agent::Agent)
    return agent.opinion
end
function setOpinion(agent::Agent, newOpinion)
    agent.opinion = newOpinion
end

agent1 = Agent("Red")
println(getOpinion(agent1))
setOpinion(agent1, "Blue")
println(getOpinion(agent1))
