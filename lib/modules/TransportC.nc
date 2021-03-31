configuration TransportC{
    provides interface Transport;
}
implementation{

    components TransportP;
    Transport = TransportP;

    components SimpleSendC(AM_PACK);
    TransportP.TSender->SimpleSendC;
}