module RoutingTableP{
    provides interface RoutingTable;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    // uses interface Receive as InternalReceiver;
    uses interface NeighborDiscovery;
    uses interface Random as RandomTimer;

}
implementation{  

    //Periodic timer for updating the routing table
    command void RoutingTable.start(){
        dbg(ROUTING_CHANNEL, "Starting Routing protoco..\n");
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

    // Print Routing Table function
    command void RoutingTable.print(){
    /*
    Outputs:
    DEBUG(1): Routing Packet -src: 3, dest: 10, seq: 0, next hop: 2, cost: 26
    DEBUG (3): Routing Table:
    DEBUG (3): Dest  Hop  Count
    DEBUG (3): 6  6  1
    */

    }

}

