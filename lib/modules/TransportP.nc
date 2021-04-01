#include "../../includes/packet.h"
#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/sendInfo.h"

module TransportP{
    provides interface Transport;
    uses interface SimpleSend as TSender;
    uses interface List<socket_store_t> as sockets;
}
implementation{

    command socket_t Transport.socket()
    {
        socket_t fd;
        socket_store_t tempSocket;
        if(call sockets.size() < MAX_NUM_OF_SOCKETS)
        {
            fd = call sockets.size();
            tempSocket.fd = call sockets.size();
            call sockets.pushback(tempSocket);
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
        tempSocket = call sockets.get(fd);
        tempSocket.fd = fd;
        tempSocket.src = addr->port;
        tempSocket.state = LISTEN;

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
        tempSocket = call sockets.get(fd);
        tempSocket.state = LISTEN;

    }
}