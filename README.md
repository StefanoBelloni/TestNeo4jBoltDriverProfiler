# TestNeo4jBoltDriverProfiler
Simple project to time the client side and server side of a intesive I/O procedure when called from python neo4j bolt driver

To run the tests it is required:
   * mvn
   * docker
   * python3
   * Neo4j Bolt Driver 1.7 for Python
   * curl
   
for the c test, comment/uncomment line 191 in ./script/run_test.sh   
   * gcc
   * c-driver

cd script
./run_test.sh

# EXAMPLE RESULTS

RESULT run_python:            
 * server: procedure returned after      798 
 * client: session.run() returned after  1916

RESULT run_rest:            
 * server: procedure returned after      435 
 * client: session.run() returned after  1.480s

When performing the population of the graph with the python function, and calling the procedure from the neo4j browser,
one gets
Started streaming 1 records after 475 ms and completed after 475 ms.
and the time on the server side is 1/2 ms lower.
