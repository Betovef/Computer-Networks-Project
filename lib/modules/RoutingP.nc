module RoutingP{
    provides interface Routing;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    // uses interface Receive as InternalReceiver;
    uses interface NeighborDiscovery;
    uses interface Random as RandomTimer;
    uses interface List<uint16_t> as NeighborList;
    uses interface Hashmap<uint16_t> as RoutingTable;

}
implementation{  

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

    //Split Horizon implementation 

    //Poison Reverse technique implementation

    //response to s.routeDMP(5);
   
    // Print Routing Table function
    command void Routing.print(){

        dbg(ROUTING_CHANNEL, "Routing Table:\n");
        dbg(ROUTING_CHANNEL, "Printing neighbors of %d: \n", TOS_NODE_ID);
        dbg(ROUTING_CHANNEL, "%d and %d: \n", call NeighborList.get(0), call NeighborList.get(1));
        
    /*
    Outputs:
    DEBUG(1): Routing Packet -src: 3, dest: 10, seq: 0, next hop: 2, cost: 26
    DEBUG (3): Routing Table:
    DEBUG (3): Dest  Hop  Count
    DEBUG (3): 6  6  1
    */

    }

}

