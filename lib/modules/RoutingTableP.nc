module RoutingTableP{
    provides interface RoutingTable;

    uses interface Timer<TMilli> as RoutingTimer;
    uses interface SimpleSend as RSender;
    uses interface Receive as InternalReceive;
    uses interface NeighborDiscovery;

}
implementation{  

    //Periodic timer for updating the routing table

    //crete struct(or header file) to store DVR information

    //RIP implementation (route advertising and merging routes)

    //Split Horizon implementation 

    //Poison Reverse technique implementation

    // Print Routing Table function

}