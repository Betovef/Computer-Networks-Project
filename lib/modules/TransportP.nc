#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"

module TransportP{
    provides interface Transport;
    uses interface SimpleSend as TSender;
    uses interface Hashmap<socket_store_t> as sockets;
}
implementation{

    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS)
        {
            fd = call sockets.size()+1;
            tempSocket.fd = fd;
            call sockets.insert(fd, tempSocket);
        }
        else
        {
            dbg(TRANSPORT_CHANNEL, "Unable to allocate socket \n");
            return NULL;
        }
        return fd;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr)
    {
        socket_store_t tempSocket; 
        socket_addr_t tempAddress; 
        if(call sockets.contains(fd)){
            tempSocket = call sockets.get(fd);
            tempAddress.port = addr->port;
            tempAddress.addr = addr->addr;
            tempSocket.dest = tempAddress;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);

            return SUCCESS;
        }
        else{
            return FAIL;
        }

    }

    command socket_t Transport.accept(socket_t fd)
    {

    }

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.receive(pack* package)
    {

    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen)
    {

    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr)
    {

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
        enum socket_state tempState;

        if(call sockets.contains(fd)){
            tempSocket = call sockets.get(fd);
            tempState = LISTEN;
            tempSocket.state = tempState;

            call sockets.remove(fd);
            call sockets.insert(fd, tempSocket);
            
            return SUCCESS;
        }
        else{
            return FAIL;
        }
    }
}