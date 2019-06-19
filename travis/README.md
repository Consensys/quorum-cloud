## Quorum Cloud: Travis 

Deploy a Quorum network with 4 nodes locally inside a Travis container.  This is useful for continuous integration testing.

### Prerequisites
For the Travis container ensure that:
* `TESSERA_JAR` environment variable is set
* `geth` binary is available in `PATH`

### Start network

```shell
git clone https://github.com/jpmorganchase/quorum-cloud.git
cd quorum-cloud/travis/4nodes
./init.sh <consensus>
./start.sh <consensus> tessera
```
Replace `<consensus>` with one of the values: `raft`/`istanbul`/`clique`

### Stop network

```
./stop.sh
```

### Example
This is currently used as part of the Quorum CI process alongside [quorum-acceptance-tests](https://github.com/jpmorganchase/quorum-acceptance-tests).  See [`travis.yml`](https://github.com/jpmorganchase/quorum/blob/master/.travis.yml), specifically the script [`build/travis-run-acceptance-tests-linux.sh`](https://github.com/jpmorganchase/quorum/blob/master/build/travis-run-acceptance-tests-linux.sh).
