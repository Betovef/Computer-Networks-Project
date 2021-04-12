#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/protocol.h"
#include "../../includes/sendInfo.h"
#include "../../includes/route.h"
#include "../../includes/tcp.h"

module TransportP{
    provides interface Transport;

    uses interface Timer<TMilli> as TransportTimer;
    uses interface SimpleSend as RSender;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface Hashmap<socket_store_t> as sockets;
}
implementation{

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    socket_t getfd(uint8_t destPort);

    event void TransportTimer.fired()
    {
        //need to work on this
    }

    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS) //check if sockets available
        {
            fd = call sockets.size()+1; //fd related to the size of the sockets storage
            tempSocket.fd = fd;
            call sockets.insert(fd, tempSocket);
            return fd;
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "Unable to allocate socket \n");
            return NULL;
        }
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
    {
        socket_store_t tempSocket; 
        if(call sockets.contains(fd)) //check if socket exists in sockets available
        {
            tempSocket = call sockets.get(fd);

            tempSocket.src.port = addr->port;
            tempSocket.src.addr = addr->addr;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);

            return SUCCESS;
        }
        else
        {
            return FAIL;
        }

    }

    command socket_t Transport.accept(socket_t fd)
    {
        pack sendPackage;
        socket_store_t tempSocket = call sockets.get(fd);

        dbg(TRANSPORT_CHANNEL, "Hello world from accept\n");
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.receive(pack* package)
    {
        tcp_segment* myMsg = (tcp_segment*)(package->payload); //unload payload
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_t fd;

        tcp_segment* TCPpack; //new payload
        pack sendPackage; //new message packet

        //Tree-way handshake
        if(myMsg->flags == SYN)
        {
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);
            dbg(TRANSPORT_CHANNEL, "SYN Packet Arrived from Node %d for Port %d\n", package->src, myMsg->srcPort);
            if(serverSocket.state == LISTEN)
            {
                //updating server socket state to SYN_RCVD
                serverSocket.state = SYN_RCVD;
                serverSocket.dest.port = myMsg->srcPort;
                serverSocket.dest.addr = package->src;
                call sockets.remove(fd);
                call sockets.insert(fd, serverSocket);

                //Setting up the response to client 
                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = serverSocket.dest.port;
                TCPpack->srcPort = serverSocket.src.port;

                //(Flags = SYN ACK, Ack = x+1, SequenceNum = y)
                TCPpack->seq = 1; // FIXME: need to give random number
                TCPpack->ACK = myMsg->seq + 1;
                TCPpack->flags = SYN_ACK;
                
                // Server received SYN message sending reply SYN+ACK 
                makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "Syn Ack Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
                call RSender.send(sendPackage, serverSocket.dest.addr); 
            }
            else
            {
                dbg(TRANSPORT_CHANNEL, "SERVER NOT LISTENING\n");
            }
        }

        else if(myMsg->flags == SYN_ACK)
        {
            dbg(TRANSPORT_CHANNEL, "SYN Ack Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort); 
            fd = getfd(myMsg->destPort);
            clientSocket = call sockets.get(fd);

            //updating client socket state to ESTABLISHED
            clientSocket.state = ESTABLISHED;
            clientSocket.dest.port = myMsg->srcPort;
            clientSocket.dest.addr = package->src;
            call sockets.remove(fd);
            call sockets.insert(fd, clientSocket);

            //Setting up the response to server
            TCPpack = (tcp_segment*)(sendPackage.payload);
            TCPpack->destPort = clientSocket.dest.port;
            TCPpack->srcPort = clientSocket.src.port;
                
            //(Flags = ACK, Ack = y + 1)
            TCPpack->ACK = myMsg->seq + 1;
            TCPpack->flags = ACK;

            // Client received SYN ACK message sending reply ACK 
            makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
            dbg(TRANSPORT_CHANNEL, "Ack Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
            call RSender.send(sendPackage, clientSocket.dest.addr); 
            call Transport.accept(fd);
        }

        else if(myMsg->flags == ACK)
        {
            dbg(TRANSPORT_CHANNEL, "Ack Packet Arrved from Node %d for Port %d \n", package->dest, myMsg->destPort); //FIXME: need to fix ports, they are being updated incorrectly
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);

            //updating server socket state to ESTABLISHED
            serverSocket.state = ESTABLISHED;
            serverSocket.dest.port = myMsg->srcPort;
            serverSocket.dest.addr = package->src;
            call sockets.remove(fd);
            call sockets.insert(fd, serverSocket);
            dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been ESTABLISHED\n");
        }

    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
    {
        pack sendPackage; //message
        tcp_segment* TCPpack; //payload

        socket_store_t clientSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        clientSocket.dest.port = addr->port; //this??????
        clientSocket.dest.addr = addr->addr;
        TCPpack->destPort = clientSocket.dest.port;
        TCPpack->srcPort = clientSocket.src.port;
        //(Flags = SYN, SequenceNum = x) NOTE: sequence number should be random
        TCPpack->ACK = 0;
        TCPpack->seq = 1;
        TCPpack->flags = SYN;

        if(call RoutingTable.contains(addr->addr)) //check if there is a route to dest (server)
        { 
            clientSocket.state = SYN_SENT; //update state
            dbg(TRANSPORT_CHANNEL, "Starting Three-Way Handshake\n");
            dbg(TRANSPORT_CHANNEL, "SYN Packet Sent to Node %d for Port %d \n", clientSocket.dest.addr, clientSocket.dest.port);
            makePack(&sendPackage, TOS_NODE_ID, addr->addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
            call RSender.send(sendPackage, addr->addr); 
            
            return SUCCESS;
        }
        else
        {
            return FAIL;
        }
    }

    command error_t Transport.close(socket_t fd)
    {

    }

    command error_t Transport.release(socket_t fd)
    {

    }

    command error_t Transport.listen(socket_t fd)
    {
        socket_store_t tempSocket;

        if(call sockets.contains(fd)) //check if socket exists
        { 
            tempSocket = call sockets.get(fd);
            tempSocket.state = LISTEN;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);
            
            return SUCCESS;
        }
        else
        {
            return FAIL;
        }
    }

    socket_t getfd(uint8_t srcPort)
    {
        socket_store_t tempSocket;
        uint8_t i;

        for(i = 0; i < call sockets.size(); i++)
        {
            tempSocket = call sockets.get(i);
            if(tempSocket.src.port == srcPort)
            {
                return i;
            }
        }
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}