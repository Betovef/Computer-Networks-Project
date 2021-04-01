configuration TransportC{
    provides interface Transport;
}
implementation{

    components TransportP;
    Transport = TransportP;

    components new SimpleSendC(AM_PACK);
    TransportP.TSender->SimpleSendC;

    components new ListC(socket_store_t, 10) as SocketsC;
    TransportP.sockets->SocketsC;
}