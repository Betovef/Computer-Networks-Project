#define AM_ROUTING 16

configuration RoutingTableC{
    provides interface RoutingTable;
}
implementation{
    components RoutingTableP;
    RoutingTable = RoutingTableP.RoutingTable;

    components new TimerMilliC() as RoutingTimer;
    RoutingTableP.RoutingTimer->RoutingTimer;

    components new SimpleSendC(AM_ROUTING);
    RoutingTableP.RSender->SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    // RoutingTableP.InternalReceiver->AMReceiverC;

    components NeighborDiscoveryC;
    RoutingTableP.NeighborDiscovery -> NeighborDiscoveryC;

    components RandomC as RandomTimer;
    RoutingTableP.RandomTimer -> RandomTimer;

    
}