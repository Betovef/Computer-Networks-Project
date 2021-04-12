#define AM_TRANSPORT 66;

configuration TransportC{
    provides interface Transport;
    uses interface Hashmap<Route> as RoutingTableC;
}
implementation{

    components TransportP;
    Transport = TransportP;
    TransportP.RoutingTable = RoutingTableC;

    // components new SimpleSendC(AM_PACK);
    // TransportP.TSender->SimpleSendC;

    components FloodingC;
    TransportP.RSender->FloodingC.RSender;

    components new HashmapC(socket_store_t, 10) as SocketsC;
    TransportP.sockets->SocketsC;

    components new TimerMilliC() as TransportTimer;
    TransportP.TransportTimer->TransportTimer;
}