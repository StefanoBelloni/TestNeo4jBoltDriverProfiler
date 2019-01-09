import functools

from neo4j.v1 import GraphDatabase
from neo4j import exceptions as neo4jexception


# ====================================
# TIMER
# ==================================== #
def timeit(func):
    @functools.wraps(func)
    def new_func(*args, **kwargs):
        import datetime
        start_time = datetime.datetime.now()
        r = func(*args, **kwargs)
        elapsed_time = datetime.datetime.now() - start_time
        print('time function {:35} .................... ms # {}'
              .format("[" + func.__name__ + "]",
                      int(elapsed_time.total_seconds() * 1000)))
        return r

    return new_func


# ======================================================================== #

class Neo4Test:

    def __init__(self,
                 uri="bolt://localhost:7687",
                 user="neo4j",
                 password="neo4j"):

        # === init neo4j credentials === #
        self.user = user
        self.password = password
        self.uri = uri
        # ==== Connect to Neo4j Server ==== #
        try:
            self._driver = GraphDatabase.driver(
                self.uri, auth=(self.user, self.password))
        except neo4jexception.ServiceUnavailable:
            raise ConnectionError("Fail to establish connection ...")

    # ================================= #

    def init_indexes(self):
        with self._driver.session() as session:
            for index_query in indexes_queries():
                r = session.run(index_query)

    @timeit
    def populate(self, s, e, n):
        if s > e:
            tmp = s
            e = s
            s = tmp
        with self._driver.session() as session:
            count = 0
            for i in range(s, e):
                count += session.write_transaction(
                    self.__run_populate, i=i, n=n)
            return count

    # ================================= #

    @timeit
    def calculate_save(self, i, j):
        with self._driver.session() as session:
            res = session.write_transaction(
                self.__run_calculate_save, i, j)
            return res

    # ================================= #

    @timeit
    def clean(self):
        with self._driver.session() as session:
            self._clean_graph_items(session)
    # ================================= #

    def _clean_graph_items(self, session):
        deleted_nodes = 1
        cum_deletion = 0
        node_types = [
            "r:BELONGS",
            "r:v_BELONGS",
            "n:parent",
            "n:v_parent",
            "n:child",
            "n:v_child",
            "n:cache",
            None
        ]
        for node_type in node_types:

            while deleted_nodes > 0:
                deleted_nodes = session.write_transaction(
                    self._clean_graph, node_type)

                cum_deletion += deleted_nodes
                print("  * cumlative delets: " + str(cum_deletion)
                      + " last result: " + str(deleted_nodes) + '\r',
                      end="")
        return cum_deletion

    # +++++++++++++++++++++++++++++++++++++++++++++++ #

    @staticmethod
    def __run_populate(tx, n, i):
        res = tx.run("CALL example.populate($n, $i) YIELD out as o RETURN o",
                     i=i, n=n)
        return res.single()["o"]

    # +++++++++++++++++++++++++++++++++++++++++++++++ #

    @staticmethod
    def __run_calculate_save(tx, i, j):
        if i > j:
            tmp = i
            j = i
            i = tmp

        res = tx.run(
            "CALL example.calculate.save($i, $j) YIELD out as o RETURN o",
            i=i, j=j)
        return res.single()["o"]

    # +++++++++++++++++++++++++++++++++++++++++++++++ #

    @staticmethod
    def _clean_graph(tx, type_node):
        return tx.run(delete_graph_query(type_node)).single().value()


# ############################################################################ #
# CLEANUP QUERIES
# ############################################################################ #

def delete_graph_query(type_node):
    if type_node is None:
        return (' MATCH (n) \n '
                ' WITH n LIMIT 5000 \n '
                ' DETACH DELETE n \n'
                ' RETURN count(*);')

    elif type_node.startswith("r:"):
        return (' MATCH ()-[' + type_node + ']->() \n '
                                            ' WITH r LIMIT 10000 \n '
                                            ' DELETE r \n'
                                            ' RETURN count(*);')

    elif type_node.startswith('n:'):
        return (' MATCH (' + type_node + ') \n '
                                         ' WITH n LIMIT 10000 \n '
                                         ' MATCH (n)-[r]-() \n'
                                         ' DELETE n,r \n'
                                         ' RETURN count(*);')
    return ""


def indexes_queries():
    return [
        ' CREATE INDEX ON :parent(value)',
        ' CREATE INDEX ON :child(value)',
    ]

# =========================================================================== #
#                      ###### #####  ##### ######                             #
#                        #    #     #        #                                #
#                        #    ###    ####    #                                #
#                        #    #          #   #                                #
#                        #    ##### #####    #                                #
# =========================================================================== #

def run_test():

    print("Connect to neo4j ...")
    d = Neo4Test()

    print("Creating indexes")
    d.init_indexes()

    print("Populating graph ...")
    count = d.populate(0, 500, 1000)
    print("  -> saved ", count, " nodes")

    print("call: 'Loading sub-graph and saving cache ...'")
    count = d.calculate_save(0, 80000)
    print("  -> saved ", count, " nodes in cache")

    print("cleanup")
    d.clean()

# =========================================================================== #

if __name__ == "__main__":
    run_test()
