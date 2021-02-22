/*
#include <headers>
source addr
monotonically increasing number sequence
TTL field
Debug channel flooding channel
Important to know which neighbor you receive a packet
add a Link Layer module w/ source and desatination addresses
have a node table for implementing a cache (contains largest sequence number seen from any node's flood)
*/
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

module FloodingP{
    provides interface SimpleSend as FSender;
    uses interface NeighborDiscovery;
    // uses interface Receive as FReceiver;

    //internal interfaces
    uses interface SimpleSend as InternalSender;
    uses interface Receive as InternalReceiver;
}
implementation{
    pack sendPackage;
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    // uint16_t src;
    // uint16_t TTL = 10;
    // uint16_t seqNum= 0;
   
    command error_t FSender.send(pack msg, uint16_t dest){
        call InternalSender.send(msg, AM_BROADCAST_ADDR);
    }

    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
      
      if(len == sizeof(pack)){
         pack* myMsg=(pack*) payload;
          //need to create function && checkPacketList(myMsg) == FALSE
        if(TOS_NODE_ID == myMsg->dest){
            dbg(GENERAL_CHANNEL, "Pinging... \n"); 
            dbg(GENERAL_CHANNEL, "Packet recieved from node %d to node %d!\n", myMsg->src, TOS_NODE_ID); 
            dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
            return msg;
        }
        else{
            makePack(&sendPackage, myMsg->src, myMsg->dest, 0, PROTOCOL_LINKEDLIST, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
            dbg(GENERAL_CHANNEL, "Package destiny: %d\n", myMsg->dest);
            call FSender.send(sendPackage, AM_BROADCAST_ADDR);
        }
        
      }
      return msg;
   }   
    //if yes, go to next neighbor, otherwise flood again

    // command FReceiver.receive(message_t* msg, void* payload, uint8_t len){

    // }

    // command FSender.send(pack* msg, uint8_t dest){
    void makePack(pack* Packet, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length)
   {
      Packet->src = src;
      Packet->dest = dest;
      Packet->TTL = TTL;
      Packet->seq = seq;
      Packet->protocol = protocol;
      memcpy(Packet->payload, payload, length);
   }
}