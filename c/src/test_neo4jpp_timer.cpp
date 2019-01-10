#include <neo4j-client.h>
#include <errno.h>
#include <stdio.h>
#include <time.h>

// ========================================================================== //
// DECLARATIONS
// ==========================================================================

int create_indexes(neo4j_connection_t* connection);
int populate_graph(neo4j_connection_t* connection);
int load_and_save(neo4j_connection_t* connection);
int cleanup(neo4j_connection_t* connection);

#define myPROFILE_FUNCTION(s,e,name, f)                               \
  clock_gettime(CLOCK_MONOTONIC, &tstart);                            \
  f;                                                                  \
  clock_gettime(CLOCK_MONOTONIC, &tend);                              \
  printf("[%s] took about ms # %.5f\n", (name),                       \
         (((double)(tend).tv_sec + 1.0e-9*(tend).tv_nsec) -           \
          ((double)(tstart).tv_sec + 1.0e-9*(tstart).tv_nsec))*1000);

// ========================================================================== //
// MAIN
// TODO: parametrize functions ...
// ========================================================================== //

int main(/*int argc, char *argv[]*/)
{
  struct timespec tstart={0,0}, tend={0,0};
  neo4j_client_init();

  /* use NEO4J_INSECURE when connecting to disable TLS */
  neo4j_connection_t *connection =
    neo4j_connect("neo4j://neo4j:neo4j1@localhost:7687", NULL, NEO4J_INSECURE);
  if (connection == NULL) {
    neo4j_perror(stderr, errno, "Connection failed");
    return EXIT_FAILURE;
  }

  // === TEST ===
  /* 
  create_indexes(connection);

  myPROFILE_FUNCTION(tstart, tend, "load_and_save",
                     populate_graph(connection))
  */
  myPROFILE_FUNCTION(tstart, tend, "calculate_save",
                     load_and_save(connection));

  cleanup(connection);
  // ============

  neo4j_close(connection);
  neo4j_client_cleanup();

  return EXIT_SUCCESS;
}

/* ========================================================================== */
/* IMPLEMENTATION                                                             */
/* ========================================================================== */

int create_indexes(neo4j_connection_t* connection)
{
  const char* indexes[] = {
    " CREATE INDEX ON :parent(value)",
    " CREATE INDEX ON :child(value)",
  };

  printf("creating indexes ... \n");
  for (int i = 0; i < 2; ++i ) {
    neo4j_result_stream_t *results =
      neo4j_run( connection, indexes[i], neo4j_null );
    neo4j_close_results(results);
  }

  return EXIT_SUCCESS;
}

/* ================================== */

int populate_graph(neo4j_connection_t* connection)
{
  printf("populating graph ... \n");

  int si_start = 0;
  int si_end = 500;
  int si_step = 1000;

  neo4j_value_t start = neo4j_int(si_start);
  neo4j_value_t step = neo4j_int(si_step);
  const char* query =
    "CALL example.populate($s, $i) YIELD out as o RETURN o";

  int count = 0;
  for (int i = si_start; i < si_end; ++i ) {
    neo4j_map_entry_t params_items[2];
    params_items[0] = neo4j_map_entry("i", start);
    params_items[1] = neo4j_map_entry("s", step);

    neo4j_value_t params = neo4j_map(params_items, 2);

    neo4j_result_stream_t *results = neo4j_run(connection, query, params);
    if (results == NULL) {
      neo4j_perror(stderr, errno, "Failed to run statement");
      return EXIT_FAILURE;
    }

    neo4j_result_t *result = neo4j_fetch_next(results);
    if (result == NULL) {
      neo4j_perror(stderr, errno, "Failed to fetch result");
      return EXIT_FAILURE;
    }

    // FIXME:
    neo4j_value_t value = neo4j_result_field(result, 0);
    count += neo4j_int_value(value);
    neo4j_close_results(results);
  }

  printf(" created %d nodes\n", count);
  
  return EXIT_SUCCESS;
}

/* ================================== */

int load_and_save(neo4j_connection_t* connection)
{
  printf("loading and saving ... \n");
  printf("  * start ... \n");

  neo4j_value_t start = neo4j_int(0);
  neo4j_value_t end = neo4j_int(80000);
  const char* query =
    "CALL example.calculate.save($i, $j) YIELD out as o RETURN o";

  neo4j_map_entry_t params_items[2];
  params_items[0] = neo4j_map_entry("i", start);
  params_items[1] = neo4j_map_entry("j", end);

  neo4j_value_t params = neo4j_map(params_items, 2);

  neo4j_result_stream_t *results = neo4j_run(connection, query, params);
  if (results == NULL) {
    neo4j_perror(stderr, errno, "Failed to run statement");
    return EXIT_FAILURE;
  }

  printf("  * fetching result ... \n");

  neo4j_result_t *result = neo4j_fetch_next(results);
  if (result == NULL) {
    neo4j_perror(stderr, errno, "Failed to fetch result");
    return EXIT_FAILURE;
  }

  /*
  printf("  * reuslt fields ... \n");
  neo4j_value_t value = neo4j_result_field(result, 0);
  char buf[128];
  printf("%s\n", neo4j_tostring(value, buf, sizeof(buf)));
  */

  neo4j_close_results(results);
  return EXIT_SUCCESS;
}

/* ================================== */

int cleanup(neo4j_connection_t* connection)
{
  printf("cleaning up ... TODO ... \n ... use python for now ...\n");
  
  return EXIT_SUCCESS;
}
