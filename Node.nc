/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/socket.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;

   uses interface NeighborDiscovery; //Added
   uses interface SimpleSend as FSender;
   uses interface SimpleSend as RSender;
   uses interface Hashmap<Route> as RoutingTable;
   uses interface List<Route> as RouteTable; //not using this -delete later
   uses interface Routing;
   uses interface Transport;
   uses interface Timer<TMilli> as clientTimer;
   uses interface Timer<TMilli> as serverTimer;
   uses interface List<socket_t> as acceptedSockets;
}

implementation{
   pack sendPackage;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   event void Boot.booted(){
      
      dbg(GENERAL_CHANNEL, "Booted\n");
      call AMControl.start();
      call Routing.initializeTable();
      call NeighborDiscovery.start();
      call Routing.start();
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
         }
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){ //runs only once

      dbg(GENERAL_CHANNEL, "PING EVENT \n"); //node x is trying to send to node y (TOS_NODE_ID to destination)
      if(call RoutingTable.contains(destination))
      {
         makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_LINKEDLIST, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
         // call Sender.send(sendPackage, AM_BROADCAST_ADDR); //destination needs to be AM_BROADCAST_ADDR (everywhere) Note- note sure if we still need this after implementing flooding
         dbg(GENERAL_CHANNEL, "Routing packet from %d to %d\n", TOS_NODE_ID, destination);
         call RSender.send(sendPackage, destination); //Starting flooding when protocol ping is called
      }
      else
      {
         makePack(&sendPackage, TOS_NODE_ID, destination, 20, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
         // call Sender.send(sendPackage, AM_BROADCAST_ADDR); //destination needs to be AM_BROADCAST_ADDR (everywhere) Note- note sure if we still need this after implementing flooding
         dbg(GENERAL_CHANNEL, "There is no route, flooding packet from node %d to %d\n", TOS_NODE_ID, destination);
         call FSender.send(sendPackage, AM_BROADCAST_ADDR); //Starting flooding when protocol ping is called
      }
      
      
   }

   event void CommandHandler.printNeighbors(){
      call NeighborDiscovery.print();
   }

   event void CommandHandler.printRouteTable(){
      call Routing.print();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   socket_addr_t serverSocketAddress;
   socket_t fd;
   event void CommandHandler.setTestServer(uint16_t port){
      dbg(TRANSPORT_CHANNEL, "Initiating server at node %d and binding it to port %d\n", TOS_NODE_ID, port);

      fd =  call Transport.socket();
      serverSocketAddress.addr = TOS_NODE_ID;
      serverSocketAddress.port = port;
      
      if(call Transport.bind(fd, &serverSocketAddress) == SUCCESS)
      {
         dbg(TRANSPORT_CHANNEL, "Server binding succesful!\n");
      }
      else{
         dbg(TRANSPORT_CHANNEL, "Server binding failed\n");
      }
      if(call Transport.listen(fd) == SUCCESS)
      {
         dbg(TRANSPORT_CHANNEL, "Server listening...\n");
      }
      else{
         dbg(TRANSPORT_CHANNEL, "Server state listening failed\n");
      }
      
      call serverTimer.startPeriodic(10000);
      //need to add timers 
   }

   event void serverTimer.fired()
   {
      socket_t newFd = call Transport.accept(fd);
      socket_t readFd;
      uint8_t i = 0;
      uint16_t dataRead = 0;
      uint8_t readBuff[SOCKET_BUFFER_SIZE];

      if(newFd != NULL)
      {
         call acceptedSockets.pushback(newFd);
      }
      if(call Transport.checkConnection(fd) == SUCCESS)
      {
         for(i = 0; i < SOCKET_BUFFER_SIZE; i++){ //prepare buffer
            readBuff[i] = 0;
         }

         for(i = 0; i < call acceptedSockets.size(); i++){ //get accepted sockets, read, and print
            readFd = call acceptedSockets.get(i);
            dataRead = call Transport.read(readFd, readBuff, SOCKET_BUFFER_SIZE);
         }
      }

   }
   
   socket_addr_t clientSocketAddress;
   uint16_t transferGlobal;

   event void CommandHandler.setTestClient(uint16_t dest, uint16_t srcPort, uint16_t destPort, uint16_t transfer){
      dbg(TRANSPORT_CHANNEL, "Initiating client at node %d and binding it to port %d\n", TOS_NODE_ID, srcPort);

      // dbg(TRANSPORT_CHANNEL, "Testing client as dest %d srcPort %d destPort %d transfer %d\n", dest, srcPort, destPort, transfer);
      fd =  call Transport.socket();
      //setting up src info
      clientSocketAddress.addr = TOS_NODE_ID;
      clientSocketAddress.port = srcPort;
      //setting up dest info
      serverSocketAddress.addr = dest;
      serverSocketAddress.port = destPort;

      //if connection succesful start timer
      dbg(TRANSPORT_CHANNEL, "Creating connection with server %d at port %d\n", dest, destPort);
      if(call Transport.bind(fd, &clientSocketAddress) == SUCCESS)
      {
         dbg(TRANSPORT_CHANNEL, "Client binding succesful!\n");
      }
      else{
         dbg(TRANSPORT_CHANNEL, "Client binding failed\n");
      }
      if(call Transport.connect(fd, &serverSocketAddress) == SUCCESS)
      {
         dbg(TRANSPORT_CHANNEL, "Server and client connection started successfully...\n");
         call clientTimer.startPeriodic(20000); //periodically write buffer
         transferGlobal = transfer;
      }
      else
      {
         dbg(TRANSPORT_CHANNEL, "Connection failed\n");
      }
   }

   event void clientTimer.fired()
    {
      uint16_t i = 0; 
      uint16_t dataWritten = 0;
      uint8_t writeBuff[transferGlobal];

      if(transferGlobal != NULL)
      {
         for(i = 0; i < transferGlobal; i++) // sending 16 bit unsigned integers from 0 to transfer
         {
            writeBuff[i] = i+1;
         }
         dataWritten = call Transport.write(fd, writeBuff, transferGlobal);
         call Transport.sendBuffer(fd);
      }
      dbg(TRANSPORT_CHANNEL, "Data written so far %d \n", dataWritten);
      if(transferGlobal - dataWritten == 0)
      {
         call clientTimer.stop();
         dbg(TRANSPORT_CHANNEL, "DATA WRITING STOPPED!!!\n");
      }
      else
      {
         transferGlobal = transferGlobal - dataWritten;
      }
    }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}
