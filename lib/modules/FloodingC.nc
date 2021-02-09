#define AM_FLOOD 13
#include "../../includes/channels.h"

configuration FloodingC{
    provides interface Flooding;
}
implementation{
    //how to call interfaces
    //Fire timer
    //Broadcast address
    //check for reply
    //if yes, go to next neighbor, otherwise flood again
    components FloodingP;
    Flooding = FloodingP.Flooding;

    components new AMReceiverC(AM_FLOOD);
    FloodingP.FReceiver -> AMReceiverC;

    components new SimpleSendC(AM_FLOOD); 
    FloodingP.FSender -> SimpleSendC;
    
}