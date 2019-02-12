Deploy Quorum network with 4 nodes locally inside a Travis container

## Prerequisites

* `TF_VAR_consensus_mechanism` variable is set (possible values are: raft/istanbul/clique)
* `TESSERA_JAR` environment variable is set
* `geth` binary is available in `PATH`