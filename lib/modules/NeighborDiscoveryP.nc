//header from Node (using the same implementation ping to ping)
#include <Timer.h>
#include "../../includes/command.h"
#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/protocol.h"

#define NEIGHBORHOOD_SIZE 4; //how many nodes do we need?
#define TIMEOUT 10; //what is a good timeout?

module NeighborDiscoveryP{
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as PeriodicTimer;
    uses interface SimpleSend as NSender;
    uses interface Receive as NReceiver;
    uses interface Random as RandomTimer;
    uses interface Hashmap<pack> as NHashmap;

}
implementation{

    pack sendPackage;
    uint32_t timer0;
    uint32_t seqCounter = 0;

    // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void updateNeighbors(); //Updates active and inactive neighbors
   void discoverNeighbors(); // 

   command void NeighborDiscovery.start(){ //command called after node booted
    timer0 = (uint16_t)((call RandomTimer.rand16())%200); //(1000 + (uint32_t)((call RandomTimer.rand32())%1000));
    dbg(NEIGHBOR_CHANNEL, "Timer fired: %d \n", timer0);
    call PeriodicTimer.startPeriodic(timer0);
   }

   command void NeighborDiscovery.print(){
      // uint16_t i = 0;

      // for(i=0; i <NList[i].size(); i++){
      //    dbg(NEIGHBOR_CHANNEL, "Neighbor discovery module works!\n");
      // }
      // return;
   }

   event void PeriodicTimer.fired()
   {
     discoverNeighbors();
   }
   void discoverNeighbors(){
         dbg(NEIGHBOR_CHANNEL, "Searching for neighbors...\n");
         makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, 0, PROTOCOL_PING, "test", PACKET_MAX_PAYLOAD_SIZE);
         call NSender.send(sendPackage, AM_BROADCAST_ADDR);
      }
   
   void updateNList(uint16_t src){
      // uint16_t i;
      // pack newNeighbor;
      // for(i = 0; i<NList.size(); i++){
      //    newNeighbor = call NList.get(i);
      //    if(newNeighbor.TTL = TIMEOUT);
      //       return;
      //    newNeighbor.src = src;
      //    newNeighbor.TTL = TIMEOUT;
      //    seqCounter++;
      // }
   }

   pack* myMsg; //why only works if outside of the function?

   event message_t* NReceiver.receive(message_t* msg, void* payload, uint8_t len){ 
      dbg(NEIGHBOR_CHANNEL, "Packet Received\n");
      myMsg=(pack*) payload;
      if(myMsg->dest == AM_BROADCAST_ADDR){ //if message destiny reaches its final destination
         myMsg->dest = myMsg->src;
         myMsg->src = TOS_NODE_ID;
         myMsg->protocol = PROTOCOL_PING;
         call NSender.send(*myMsg, myMsg->dest);
      }
      // else if(myMsg->dest == TOS_NODE_ID){
      //    //refresh timeout
      //    uint16_t i;
      //    pack isNeighborInList;
      //    for(i=0; i< call NList.size(); i++){
      //       isNeighborInList = call NList.get(i);
      //       if(isNeighborInList.src == myMsg->src){
      //          isNeighborInList.TTL = TIMEOUT;
      //       }
      //    }
      //    isNeighborInList = call NList.get(seqCounter);
      //    isNeighborInList.src = myMsg->src;
      //    seqCounter++;

      // }
      dbg(NEIGHBOR_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }

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