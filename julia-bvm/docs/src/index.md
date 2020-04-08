
# Binary Voter Model

A simulation to reproduce the original Binary Voter Model of Clifford and
Sudbury 1973[^1] and Holley and Liggett 1975[^2].

```@meta
CurrentModule = bvm
```

```@docs
run_sim(n=20, p=0.2, make_anim=false, influencer=false, replacement=false)
param_sweep(num_runs=10, this_n=20, this_p=0.2, influencer=false, replacement=false)
conf_int_sweep(num_trials=10, this_n=20, influencer=false, replacement=false)
make_graph(n, p)
set_opinion(graph, node_list, agent_list, random_influencer::Bool,
    replacement::Bool)
count_opinions(agent_list, o::Opinion, x::Int)
```

# References

[^1]: Clifford, P., & Sudbury, A. (1973). A Model for Spatial Conflict. Biometrika, 60(3), 581–588. https://doi.org/10.2307/2335008
[^2]: Holley, & Liggett. (1975). Ergodic theorems for weakly interacting systems and the voter model.


