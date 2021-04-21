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
    // uses interface Timer<TMilli> as clientTimer;
    uses interface SimpleSend as RSender;
    uses interface Hashmap<Route> as RoutingTable;
    uses interface Hashmap<socket_store_t> as sockets;
    uses interface List<socket_t> as acceptList;
}
implementation{

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
    socket_t getfd(uint8_t destPort);

    event void TransportTimer.fired()
    {
        //need to work on this
    }

    // event void clientTimer.fired()
    // {
    //     dbg(TRANSPORT_CHANNEL, "NEED TO WRITE DATA!!!\n");
        
    // }

    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        uint16_t i = 0;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS) //check if sockets available
        {
            fd = call sockets.size()+1; //fd related to the size of the sockets storage
            
            // This is the sender portion
            tempSocket.fd = fd;
            tempSocket.effectiveWindow = 0;
            tempSocket.lastWritten = 0;
            tempSocket.lastAck = 0;
            tempSocket.lastSent = 0;

            for(i = 0; i < SOCKET_BUFFER_SIZE; i++){
                tempSocket.sendBuff[i] = 0;
                tempSocket.rcvdBuff[i] = 0;
            }

            // This is the receiver portion
            tempSocket.lastRead = 0;
            tempSocket.lastRcvd = 0;
            tempSocket.nextExpected = 0;
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

            
            call sockets.insert(fd, tempSocket);

            return SUCCESS;
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "ERROR: Binding failed socket %d not found\n", fd);
            return FAIL;
        }

    }

    command socket_t Transport.accept(socket_t fd)
    {
        uint8_t i  = 0;
        socket_t tempFd;
        for(i = 0; i < call acceptList.size(); i++)
        {
            tempFd = call acceptList.get(i); //if socket is already accepted return null
            if(tempFd == fd){
                return fd;
            }
        }
        return NULL;
    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        pack sendPackage;
        socket_store_t clientSocket;
        uint16_t count = 0;
        uint16_t i = 0;
        uint16_t temp = 0;
        
        dbg(TRANSPORT_CHANNEL, "Writing data from fd %d..\n", fd);

        if(call sockets.contains(fd))
        {
            clientSocket = call sockets.get(fd);
            dbg(TRANSPORT_CHANNEL, "WHAT IS GOIGN ON in here %d\n", clientSocket.dest.addr);
        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR: socket list does not contain fd \n");
            return NULL;
        }

        // dbg(TRANSPORT_CHANNEL, "WHAT IS GOIGN ON %d\n", clientSocket.effectiveWindow);

        while(i < TCP_MAX_PAYLOAD_SIZE && i < clientSocket.effectiveWindow){
            clientSocket.sendBuff[i] = buff[i];
            clientSocket.lastWritten = buff[i];
            dbg(TRANSPORT_CHANNEL, " Writing %d\n", clientSocket.sendBuff[i]);
            i++;
        }

        
        call sockets.insert(fd, clientSocket);

        return (i+1);

    }

    command error_t Transport.receive(pack* package)
    {
        tcp_segment* myMsg = (tcp_segment*)(package->payload); //unload payload
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_store_t tempSocket;
        socket_t fd;
        uint16_t i;

        tcp_segment* TCPpack; //new payload
        pack sendPackage; //new message packet

        //Three-way handshake
        if(myMsg->flags == SYN)
        {
            fd = getfd(myMsg->destPort);
            serverSocket = call sockets.get(fd);
            dbg(TRANSPORT_CHANNEL, "SYN Packet Arrived from Node %d for Port %d\n", package->src, myMsg->srcPort);
            if(serverSocket.state == LISTEN)
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
                    serverSocket.effectiveWindow = 5;
                    
                    call sockets.insert(fd, serverSocket);

                    //Setting up the response to client 
                    TCPpack = (tcp_segment*)(sendPackage.payload);
                    TCPpack->destPort = serverSocket.dest.port;
                    TCPpack->srcPort = serverSocket.src.port;

                    //(Flags = SYN ACK, Ack = x+1, SequenceNum = y)
                    TCPpack->seq = 1; // FIXME: need to give random number
                    TCPpack->ACK = myMsg->seq + 1;
                    TCPpack->flags = SYN_ACK;
                    TCPpack->advWindow = serverSocket.effectiveWindow; //avertise window to 5
                    
                    // Server received SYN message sending reply SYN+ACK 
                    makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                    dbg(TRANSPORT_CHANNEL, "Syn Ack Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
                    call RSender.send(sendPackage, serverSocket.dest.addr); 
                }
                else
                {
                    dbg(TRANSPORT_CHANNEL, "SERVER NOT LISTENING\n");
                    //may be add retransmission ??
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
                // dbg(TRANSPORT_CHANNEL, "The effective window for the client end is %d \n", myMsg->advWindow);
                clientSocket.effectiveWindow = myMsg->advWindow;
                
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
                call acceptList.pushback(fd);
                // call clientTimer.startOneShot(15000);
                // dbg(TRANSPORT_CHANNEL, "Client ready to write DATA starting STOP AND WAIT PROTOCOL\n");
            }
            else if(myMsg->flags == ACK)
            {
                dbg(TRANSPORT_CHANNEL, "Ack Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort); 
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);

                //updating server socket state to ESTABLISHED
                serverSocket.state = ESTABLISHED;
                serverSocket.dest.port = myMsg->srcPort;
                serverSocket.dest.addr = package->src;

                
                call sockets.insert(fd, serverSocket);

                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been ESTABLISHED\n");
                call acceptList.pushback(fd);  
            }
        }
        else if(myMsg->flags == DATA || myMsg->flags == DATA_ACK){
            //DATA TRANSPORT CONTROL
            if(myMsg->flags == DATA)
            {
                dbg(TRANSPORT_CHANNEL, "Data Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);
                fd = getfd(myMsg->destPort);
                serverSocket = call sockets.get(fd);

                for(i = 0; i < serverSocket.effectiveWindow; i++){
                    serverSocket.rcvdBuff[i] = myMsg->data[i];
                    serverSocket.lastRcvd = myMsg->data[i];
                    // dbg(TRANSPORT_CHANNEL, "writing rcvdBuff %d \n ", serverSocket.rcvdBuff[i]);
                }

                
                call sockets.insert(fd, serverSocket);

            }
            else if(myMsg->flags == DATA_ACK)
            {
                dbg(TRANSPORT_CHANNEL, "Data Ack Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);
                fd = getfd(myMsg->destPort);
                clientSocket = call sockets.get(fd);

                clientSocket.lastAck = myMsg->ACK;
                clientSocket.effectiveWindow = myMsg->advWindow;

                dbg(TRANSPORT_CHANNEL, "Client destination IS %d \n", clientSocket.dest.addr);
                dbg(TRANSPORT_CHANNEL, "LAST INTEGER IS %d \n", clientSocket.lastSent);
                dbg(TRANSPORT_CHANNEL, "Client lastAck is %d\n", clientSocket.lastAck);
                dbg(TRANSPORT_CHANNEL, "Client effective window  is %d\n", clientSocket.effectiveWindow);

                
                call sockets.insert(fd, clientSocket);

            }
        }
        else{
                //TERMINATION CLOSING CONNECTION
            if(myMsg->flags == FIN)
            {
                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                dbg(TRANSPORT_CHANNEL, "FIN Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);

                //updating side to CLOSED
                tempSocket.state = CLOSED;
                tempSocket.dest.port = myMsg->srcPort;
                tempSocket.dest.addr = package->src;

                TCPpack = (tcp_segment*)(sendPackage.payload);
                TCPpack->destPort = tempSocket.dest.port;
                TCPpack->srcPort = tempSocket.src.port;
                TCPpack->seq = 1;
                TCPpack->ACK = myMsg->seq + 1;
                TCPpack->flags = FIN_ACK;
                
                call sockets.insert(fd, tempSocket);

                makePack(&sendPackage, TOS_NODE_ID, tempSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Sent to Node %d for Port %d \n", tempSocket.dest.addr, tempSocket.dest.port);

            }
            else if(myMsg->flags == FIN_ACK)
            {
                dbg(TRANSPORT_CHANNEL, "FIN ACK Packet Arrived from Node %d for Port %d \n", package->src, myMsg->srcPort);

                fd = getfd(myMsg->destPort);
                tempSocket = call sockets.get(fd);

                tempSocket.state = CLOSED;
                dbg(TRANSPORT_CHANNEL, "Connection Client/Server has been CLOSED\n");
            } 
        }    
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {
        // pack sendPackage;
        socket_store_t serverSocket;
        // uint16_t dataNotWritten;
        uint8_t i = 0;
        uint8_t temp = 0;

        dbg(TRANSPORT_CHANNEL, "Reading socket %d \n", fd);

        serverSocket = call sockets.get(fd);
        for(i = 0; i <5; i++)
        {
            temp = serverSocket.rcvdBuff[i];

            dbg(TRANSPORT_CHANNEL, "Read %d in server buffer\n", temp);
        }

        return (i+1);

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
    {
        pack sendPackage; //message
        tcp_segment* TCPpack; //payload

        socket_store_t clientSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        clientSocket.dest.port = addr->port;
        clientSocket.dest.addr = addr->addr;
        TCPpack->destPort = clientSocket.dest.port;
        TCPpack->srcPort = clientSocket.src.port;

        //(Flags = SYN, SequenceNum = x) NOTE: sequence number should be random
        TCPpack->ACK = 0;
        TCPpack->seq = 1;
        TCPpack->flags = SYN;
        TCPpack->advWindow = SOCKET_BUFFER_SIZE;

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
        //start here
        /*
        send out remaining data and a FIN packet
        Wait until recieve remaining ACK - Become FIN_WAIT_2
        One recieving a FIN from other node, become TIME_WAIT
        Until it becomes CLOSED
        If both nodes close:
            FIN is sent
            Once ACK+FIN is received, same process
        */
        /*
        FIN_WAIT_2
        TIME_WAIT
        CLOSED
        */
        /*
        socket_store_t serverSocket;
        socket_store_t clientSocket;
        socket_store_t tempSocket;
        uint16_t i;
        pack sendPackage;

        tempSocket = call sockets.get(fd);
        tempSocket.dest.port = myMsg->srcPort;
        tempSocket.dest.addr = package->src;

        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = tempSocket.dest.port;
        TCPpack->srcPort = tempSocket.src.port;
        TCPpack->seq = 1;
        TCPpack->ACK = myMsg->seq + 1;
        TCPpack -> flags = FIN;

        makePack(&sendPackage, TOS_NODE_ID, tempSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
        call RSender.send(sendPackage, addr->addr);
        if (myMsg -> flags ==FIN_ACK){}
        */
        dbg(TRANSPORT_CHANNEL, "Starting Teardown\n");
        dbg(TRANSPORT_CHANNEL, "Connection Terminated\n");
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

    command error_t Transport.sendBuffer(uint8_t fd)
    {
        socket_store_t clientSocket;
        tcp_segment* TCPpack;
        pack sendPackage;
        uint16_t i = 0;

        clientSocket = call sockets.get(fd);
        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = clientSocket.dest.port;
        TCPpack->srcPort = clientSocket.src.port;
        TCPpack->flags = DATA;

        // TCPpack = (tcp_segment*)(sendPackage.payload);
        if(call sockets.contains(fd)){

            dbg(TRANSPORT_CHANNEL, "WHAT IS GOIGN ON %d == %d \n", clientSocket.lastAck, clientSocket.lastSent);
            if(clientSocket.sendBuff[0] == 1){
                TCPpack->seq = 0;
                TCPpack->ACK = 1;
                TCPpack->flags = DATA;

                for(i = 0; i < clientSocket.effectiveWindow; i++){
                    TCPpack->data[i] = clientSocket.sendBuff[i];
                    clientSocket.lastSent = TCPpack->data[i];
                }
                dbg(TRANSPORT_CHANNEL, "Last integer sent is %d \n", clientSocket.lastSent);
                
                call sockets.insert(fd, clientSocket);

                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, clientSocket.dest.addr);
                return SUCCESS;
            }
            else if(clientSocket.lastAck == clientSocket.lastSent){
                TCPpack->seq++;
                TCPpack->flags = DATA;

                for(i = 0; i < clientSocket.effectiveWindow; i++){
                    TCPpack->data[i] = clientSocket.sendBuff[i];
                    clientSocket.lastSent = TCPpack->data[i];
                    // dbg(TRANSPORT_CHANNEL, "TCP data payload is %d \n", TCPpack->data[i]);
                }
                
                call sockets.insert(fd, clientSocket);

                makePack(&sendPackage, TOS_NODE_ID, clientSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
                call RSender.send(sendPackage, clientSocket.dest.addr);
                return SUCCESS;
            }
            else{
                return FAIL;
            }

        }
        else{
            dbg(TRANSPORT_CHANNEL, "ERROR in sendBuffer: socket list does not contain fd \n");
            return FAIL;
        }
        // socket_store_t tempSocket = call sockets.get(fd);
    }

    command error_t Transport.sendAck(uint8_t fd){

        socket_store_t serverSocket;
        tcp_segment* TCPpack;
        pack sendPackage;

        serverSocket = call sockets.get(fd);

        TCPpack = (tcp_segment*)(sendPackage.payload);
        TCPpack->destPort = serverSocket.dest.port;
        TCPpack->srcPort = serverSocket.src.port;
        TCPpack->advWindow = 5;
        TCPpack->flags = DATA_ACK;

        //(Flags = SYN ACK, Ack = x+1, SequenceNum = y) //need to fix this
        // TCPpack->seq = myMsg->seq+1; 
        TCPpack->ACK = serverSocket.lastRcvd;
        dbg(TRANSPORT_CHANNEL, "The last received from server is %d \n", serverSocket.lastRcvd);
        // TCPpack->flags = DATA_ACK;
        // TCPpack->advWindow = 5;
        
        // serverSocket = call sockets.get(fd);

        // serverSocke
        dbg(TRANSPORT_CHANNEL, "Syn Ack Packet Sent to Node %d for Port %d\n", serverSocket.dest.addr, serverSocket.dest.port);
        makePack(&sendPackage, TOS_NODE_ID, serverSocket.dest.addr, 20, PROTOCOL_TCP, 0, TCPpack, PACKET_MAX_PAYLOAD_SIZE);
        call RSender.send(sendPackage, serverSocket.dest.addr);
    }

    command error_t Transport.checkConnection(uint8_t fd){
        uint8_t i = 0;
        uint8_t temp = 0;
        for(i = 0; i < call acceptList.size(); i++){
            temp = call acceptList.get(i);
            if(temp == fd){
                return SUCCESS;
            }
        }
        return FAIL;
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