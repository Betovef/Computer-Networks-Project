#define AM_ROUTING 16

configuration RoutingC{
    provides interface Routing;
    uses interface List<uint16_t> as NeighborListC;
    uses interface Hashmap<uint16_t> as HashmapC;
    uses interface List<Route> as RouteTableC;
}
implementation{
    components RoutingP;
    Routing = RoutingP.Routing;
    RoutingP.RoutingTable = HashmapC;
    RoutingP.RouteTable = RouteTableC;

    components new TimerMilliC() as RoutingTimer;
    RoutingP.RoutingTimer->RoutingTimer;

    components new SimpleSendC(AM_ROUTING);
    RoutingP.RSender->SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    // RoutingTableP.InternalReceiver->AMReceiverC;

    components NeighborDiscoveryC;
    RoutingP.NeighborDiscovery -> NeighborDiscoveryC;
    RoutingP.NeighborList = NeighborListC;

    components RandomC as RandomTimer;
    RoutingP.RandomTimer -> RandomTimer;

    
}