#ifndef ROUTE_H
#define ROUTE_H

typedef nx_struct Route{
    nx_uint16_t src; //address of link
    nx_uint16_t dest; //address of destination
     nx_uint16_t seq; //age of routingpacket
    nx_uint16_t nextHop; //address of next hop
    nx_uint16_t cost; //distance metric
}Route;

#endif