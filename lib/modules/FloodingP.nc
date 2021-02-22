#include <headers>
/*
source addr
monotonically increasing number sequence
TTL field
Debug channel flooding channel
Important to know which neighbor you receive a packet
add a Link Layer module w/ source and desatination addresses
have a node table for implementing a cache (contains largest sequence number seen from any node's flood)
*/
module FloodingP{
    Provides interface Flooding;
    
    uses interface SimpleSend as NSender;
    uses interface Receive as NReceiver;
    uses interface Random as RandomTimer;
    uses interface List<pack> as NList;
    uses interface Timer<TMilli> as PeriodicTimer;
}
implementation{
    pack sendPackage;
    uint16_t src;
    uint16_t TTL = 10;
    uint16_t seqNum= 0;
    uint16_t timer2;
    uint16_t timer1;
    //how to call interfaces
    //Fire timer
    //Broadcast address
    //check for reply
    bool checkReply();
    //if yes, go to next neighbor, otherwise flood again

    // command FReceiver.receive(message_t* msg, void* payload, uint8_t len){

    // }

    // command FSender.send(pack* msg, uint8_t dest){
}
