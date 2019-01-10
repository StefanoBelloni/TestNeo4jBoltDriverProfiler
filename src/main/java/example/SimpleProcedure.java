package example;

import java.util.*;
import java.util.stream.Stream;
import org.neo4j.graphdb.*;
import org.neo4j.logging.Log;
import org.neo4j.procedure.*;

/**
 * This is an example showing how you could expose Neo4j's full text indexes as
 * two procedures - one for updating indexes, and one for querying by label and
 * the lucene query language.
 */
public class SimpleProcedure
{
    @Context
    public GraphDatabaseService db;

    @Context
    public Log log;

    static Random ran = new Random();

    /* <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> */

    /**
     * Sample
     */
    @Procedure(
            value = "example.populate",
            mode = Mode.WRITE
    )
    @Description("Execute lucene query in the given index, return found nodes")
    public Stream<QueryCount> populate(
            @Name("step") Long n,
            @Name("value") Long l)
    {

        log.info("populate ... start");
        log.info("step is: " + n);
        log.info("value is: " + l);
        FunctionTimer timer = new FunctionTimer();
        timer.startTimer("populate");
        try (Transaction tx = db.beginTx()) {

            for (long i = l*n; i < (l + 1)*n ; ++i) {

                Node p = db.createNode(parent);
                p.setProperty(VALUE, i);
                for (long j = 0L; j < 4 + ran.nextInt(5); ++j) {
                   Node c = db.createNode(child);
                   c.setProperty(VALUE, i);
                   c.createRelationshipTo(p, RelTypes.BELONGS);
                   ++i;
                }

            }

            tx.success();

        }

        log.info(timer.stopTimer());
        return Stream.of(new QueryCount( ( l*(n+1L)) ) );

    }

    /* <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> */

    /**
     * Sample
     */
    @Procedure(
            value = "example.calculate.save",
            mode = Mode.WRITE
    )
    @Description("Execute lucene query in the given index, return found nodes")
    public Stream<QueryCount> calulate_and_save(
            @Name("start") Long start,
            @Name("end") Long end )
    {

        log.info("calulate_and_save");
        log.info("start is: " + start);
        log.info("end is: " + end);
        Map<Long, List<Node>> nodesMap = new HashMap<>();

        FunctionTimer timer = new FunctionTimer();
        FunctionTimer timer_all = new FunctionTimer();
        timer_all.startTimer("calculate_and_save");
        int n_nodes = 0;
        timer.startTimer("loading nodes ...");
        for ( Long i = start; i < end; ++i ) {
            ResourceIterator<Node> n;
            try {
                n = db.findNodes(parent, VALUE, i);
            } catch (org.neo4j.graphdb.NotFoundException e ) {
                continue;
            }
            List<Node> nodes = new ArrayList<>();
            while(n.hasNext()) {
               Node nn = n.next();
               for (Relationship r : nn.getRelationships(RelTypes.BELONGS)) {
                  Node n_c = r.getOtherNode(nn);
                  nodes.add(n_c);
                  n_nodes++;
               }
            nodesMap.put(i, nodes);
            }
        }
        log.info(timer.stopTimer());
        log.info("read and saved  ");
        log.info("  * parents", nodesMap.size());
        log.info("  * child-nodes", n_nodes);

        timer.startTimer("nodes not cached ...");
        Node c = db.findNode(
                    v_cache,
                    VALUE,
                    String.valueOf(start) + String.valueOf(end));
        if ( c != null ) {
           log.info("node exists ... returning ");
           return Stream.of(new QueryCount(0L));
        }

        log.info("node does not exists ... saving cache ");

        Long count = 0L;
        log.info(" * create cache node");
        Node n = db.createNode(v_cache);
        n.setProperty(NAME,
                String.valueOf(start) + String.valueOf(end));

        log.info(" * start saving");
        for (Long id : nodesMap.keySet()) {
            count++;
            Node p = db.createNode(v_parent);
            p.setProperty(VALUE, id);
            for (Node h : nodesMap.get(id)) {
                count++;
                Node c_n = db.createNode(v_child);
                c_n.setProperty(VALUE,
                                h.getProperty(VALUE));
                c_n.createRelationshipTo(p, v_RelTypes.v_BELONGS);
            }
        }

        log.info(" * count saved ndoes: ", count);
        log.info(timer.stopTimer());

        log.info(timer_all.stopTimer());
        return Stream.of(new QueryCount(count));
    }

    /* === = === = === = === = === */

    public class QueryCount
    {
        @SuppressWarnings({"WeakerAccess", "unused"})
        public final Long out;

        @SuppressWarnings("WeakerAccess")
        public QueryCount(Long o_)
        {
            out = o_;
        }
    }

    /* === = === = === = === = === */

    static final String VALUE = "value";
    static final String NAME = "name";
    static final Label parent = Label.label("parent");
    static final Label child = Label.label("child");
    enum RelTypes implements RelationshipType
    {
        BELONGS,
    }

    /* === = === = === = === = === */

    static final Label v_cache = Label.label("v_cache");
    static final Label v_parent = Label.label("v_parent");
    static final Label v_child = Label.label("v_child");

    enum v_RelTypes implements RelationshipType
    {
        v_BELONGS,
    }

}
