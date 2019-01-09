# TestNeo4jBoltDriverProfiler
Simple project to time the client side and server side of a intesive I/O procedure when called from python neo4j bolt driver

To run the tests it is required:
   * mvn
   * docker
   * python3
   * Neo4j Bolt Driver 1.7 for Python

cd script
./run_test.sh

# EXAMPLE RESULTS
Times load and save sub-graph:
 * server: procedure returned after      1718 
 * client: session.run() returned after  3004

 * When calling the procedure from the neo4j browser, the time measured is closer to the one on the server side.
