#ifndef LS_H
#define LSP_H

// enum{
//     MAX_LSP = 20;
// };

typedef nx_struct LSP{
    nx_uint16_t src; //node that created the LSP
    nx_uint16_t dest; //node from which the LSP was recieved
    nx_uint16_t seq; //cost in hops
    nx_uint16_t nextHop;
    nx_uint16_t cost;
}LSP;

#endif