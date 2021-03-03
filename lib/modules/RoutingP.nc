#include "../../includes/route.h"

#define TABLE_SIZE 8 //change value accordingly

module RoutingP{
    provides interface Routing;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    // uses interface Receive as InternalReceiver;
    uses interface NeighborDiscovery;
    uses interface Random as RandomTimer;
    uses interface List<uint16_t> as NeighborList;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface List<Route> as RouteTable;

}
implementation{  
    uint16_t i;
    uint16_t listSize;
    Route packet; 

    //Periodic timer for updating the routing table
    command void Routing.start(){
        // dbg(ROUTING_CHANNEL, "Starting Routing protoco..\n");
        call RoutingTimer.startPeriodic(10000 + (uint16_t)((call RandomTimer.rand16())%10000)); 
    }

    event void RoutingTimer.fired(){

        // call Routing.initializeTable();
    }

    command void Routing.initializeTable(){
        Route newPacket;
        for(i = 1; i< TABLE_SIZE; i++){
            newPacket.dest = i;
            newPacket.cost = 255; // "infinity"
            call RoutingTable.insert(i, newPacket);
        }
    }

    command void mergeRoutes(){
        

    } 

    // event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
    //     return msg;
    // }


    //RIP implementation (route advertising and merging routes)
    /*  
        Node tells immediate neighbors of dist to all other nodes
        Create and update routing table
        Determine next-hop and shortest paths
        Send packet using next-hops as directed by routing table
    */
    //Split Horizon implementation 
        //More info on project2notes.txt
        /*
        Example: A-B-C
        router A learns about C through B
        if A learned about C through B
            A will not send info about C to B
        */
    //Poison Reverse technique implementation
        //More info on project2notes.txt
        /*
        if route is unreachable
            route == inf
            broadcast to other nodes/routers
        */

    // Print Routing Table function (response to s.routeDMP())
    //The entire routing table should be printed when the command routingTableDump is called
    command void Routing.print(){

        dbg(ROUTING_CHANNEL, "Routing Table:\n");
        dbg(ROUTING_CHANNEL, "Dest\t Hop\t Count\n");
        // listSize = call RouteTable.size();

        // for(i = 0; i< TABLE_SIZE; i++){
        //     packet = call RouteTable.get(i);
        //     dbg(ROUTING_CHANNEL, "%d\t %d\t %d\n", packet.dest, packet.nextHop, packet.cost);
        // }

        listSize = call RoutingTable.size();

        for(i = 1; i< TABLE_SIZE; i++){
            packet = call RoutingTable.get(i);
            dbg(ROUTING_CHANNEL, "%d\t %d\t %d\n", packet.dest, packet.nextHop, packet.cost);
        }
    }

}

