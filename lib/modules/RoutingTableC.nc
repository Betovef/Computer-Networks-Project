#define AM_ROUTING 16

configuration RoutingTableC{
    provides interface RoutingTable;
}
implementation{
    componets RoutingTable;
    RoutingTable = RoutingTableP.RoutingTable;

    components new TimerMillic() as RoutingTimer;
    RoutingTableP.RoutingTimer->RoutingTimer;

    components new SimpleSendC(AM_ROUTING);
    RoutingTable.RoutingSender->SimpleSendC;

    components new AMReceiverC(AM_ROUTING);
    RoutingTableP.MainReceive->AMReceiverC;

    components NeighborDiscoveryC;
    RoutingTableP.NeighborDiscovery -> NeighborDiscoveryC;

    
}