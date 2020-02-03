using LightGraphs
using GraphPlot
using Random

@enum Opinion Red Blue
function make_graph()
    n = 20
    p = 0.2
    graph = erdos_renyi(n,p)
    while is_connected(graph) == false
        graph = erdos_renyi(n,p)
    end
    node_list = vertices(graph)
    agent_list = []
    opin_list = (Red::Opinion, Blue::Opinion)
    for n in node_list
        this_opinion = rand(opin_list)
        push!(agent_list, Agent(this_opinion))
    end
    uniform = false
    while uniform == false
        uniform = true
        for i in 1:n-1
            if getOpinion(agent_list[i]) != getOpinion(agent_list[i+1])
                uniform = false
                break
            end
        end
        this_node = rand(node_list)
        this_agent = agent_list[this_node]
        neighbor_list = neighbors(graph, this_node)
        next_node = rand(neighbor_list)
        next_agent = agent_list[next_node]
        next_opinion = getOpinion(next_agent)
        setOpinion(this_agent, next_opinion)
    end
    gplot(graph)
end
