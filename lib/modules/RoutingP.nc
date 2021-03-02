#include "../../includes/route.h"

module RoutingP{
    provides interface Routing;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    // uses interface Receive as InternalReceiver;
    uses interface NeighborDiscovery;
    uses interface Random as RandomTimer;
    uses interface List<uint16_t> as NeighborList;
    uses interface Hashmap<uint16_t> as RoutingTable;
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

    }

    // event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
    //     return msg;
    // }

    //crete struct(or header file) to store DVR information

    //RIP implementation (route advertising and merging routes)
    /*

    */
    //Split Horizon implementation 
    /*
    Prevents routing loops in protocol by preventing a router from broadcasting a route back onto the interface from which it was learned.
    Example: if a-b-c and a sends to c, a does not have to advertise its route for c back to b
    */
    //Poison Reverse technique implementation
    /*
    Prevents router from sending packets through a route that has become invalid
    If an invalid/unreachable route is detected, all other routers are informed that the bad route has a inf route metric (make it very long or infinite)
    */
    // Print Routing Table function (response to s.routeDMP())
    command void Routing.print(){

        dbg(ROUTING_CHANNEL, "Routing Table:\n");
        dbg(ROUTING_CHANNEL, "Dest\t Hop\t Count\n");
        listSize = call RouteTable.size();

        for(i = 0; i< listSize; i++){
            packet = call RouteTable.get(i);
            dbg(ROUTING_CHANNEL, "%d\t %d\t %d\n", packet.dest, packet.nextHop, packet.cost);
        }
        
        
    /*
    Outputs:
    DEBUG(1): Routing Packet -src: 3, dest: 10, seq: 0, next hop: 2, cost: 26
    DEBUG (3): Routing Table:
    DEBUG (3): Dest  Hop  Count
    DEBUG (3): 6  6  1
    */

    }

}

