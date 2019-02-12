Deploy Quorum network with 4 nodes locally inside a Travis container

**Note:** This is mainly used for continous integration

## Prerequisites

* `TESSERA_JAR` environment variable is set
* `geth` binary is available in `PATH`

## Start network

```shell
git clone https://github.com/jpmorganchase/quorum-cloud.git
cd quorum-cloud/travis/4nodes
./init.sh <consensus>
./start.sh <consensus> tessera
```
Replace `<consensus>` with one of the values: raft/istanbul/clique

## Stop network

```
./stop.sh
```